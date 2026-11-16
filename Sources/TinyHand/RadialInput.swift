import AppKit

/// The existing InputTap calls this before drawing routing. No second tap.
/// Flags and ordinary keyboard pairs always pass unchanged. Claimed mouse and
/// Escape pairs drain after dismissal, deactivation, or an eligibility change.
final class RadialInput {
    enum Event { case open(CGPoint), move(CGPoint), release, click(CGPoint), cancel }
    var onEvent: ((Event) -> Void)?
    private let lock = NSLock()
    private var trigger: RadialTrigger?
    private var eligible = false
    private var held = false
    private var open = false
    static let holdDuration: TimeInterval = 0.180
    private struct Pending { let id: UInt; let deadline: TimeInterval; var point: CGPoint }
    private var pending: Pending?
    private var sequence: UInt = 0
    private var reconciledReleases = 0
    private let clock: () -> TimeInterval
    init(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) { self.clock = clock }
    private var buttons = Set<Int64>()
    private var keys = Set<Int64>()
    var needsTap: Bool { lock.withLock { (trigger != nil && eligible) || !buttons.isEmpty || !keys.isEmpty } }
    var diagnostics: [String: Any] { lock.withLock { ["open": open, "held": held, "buttons": buttons.sorted(), "keys": keys.sorted(), "eligible": eligible, "pending": pending != nil, "reconciledReleases": reconciledReleases] } }
    /// Existing pair ownership takes precedence over another surface's new claims.
    func ownsPair(_ type: CGEventType, event: CGEvent) -> Bool {
        lock.withLock {
            switch type {
            case .keyDown, .keyUp: return keys.contains(event.getIntegerValueField(.keyboardEventKeycode))
            case .leftMouseDown, .leftMouseUp, .leftMouseDragged: return buttons.contains(0)
            case .rightMouseDown, .rightMouseUp, .rightMouseDragged: return buttons.contains(1)
            case .otherMouseDown, .otherMouseUp, .otherMouseDragged: return buttons.contains(event.getIntegerValueField(.mouseEventButtonNumber))
            default: return false
            }
        }
    }
    func configure(trigger: RadialTrigger?, eligible: Bool, flags: CGEventFlags = []) {
        lock.withLock {
            if self.trigger != trigger || !eligible { cancel() }
            if self.trigger != trigger || (!self.eligible && eligible) {
                held = trigger.map { flags.contains($0.flag) } ?? false
            }
            self.trigger = trigger; self.eligible = eligible
            // The service tick samples native flags even while closed. A missed
            // flagsChanged release must not leave the next gesture latched out.
            reconcileRelease(flags)
        }
    }
    func end() { lock.withLock { pending = nil; open = false } }
    func suspendForSystem(releasingButton: Int64?, key: Int64?) {
        lock.withLock {
            cancel(); eligible = false; held = false
            if let releasingButton { buttons.remove(releasingButton) }
            if let key { keys.remove(key) }
        }
    }
    private func send(_ event: Event) {
        DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
    }
    private func cancel() { pending = nil; if open { open = false; send(.cancel) } }
    private func reconcileRelease(_ flags: CGEventFlags) {
        if held, let trigger, !flags.contains(trigger.flag) {
            reconciledReleases += 1
            held = false
            cancel() // A sampled release cancels rather than selecting a stale target.
        }
    }
    /// Timer and deterministic tests share the same deadline/eligibility check.
    func advanceHold(flags: CGEventFlags, dragging: Bool, now: TimeInterval? = nil) {
        lock.withLock {
            reconcileRelease(flags)
            guard let pending, (now ?? clock()) >= pending.deadline else { return }
            self.pending = nil
            guard let trigger, held, eligible, !dragging, buttons.isEmpty, keys.isEmpty,
                  flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]) == trigger.flag else { return }
            open = true
            send(.open(pending.point))
        }
    }
    private func beginHold(at point: CGPoint) {
        sequence &+= 1
        let id = sequence
        pending = Pending(id: id, deadline: clock() + Self.holdDuration, point: point)
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + Self.holdDuration) { [weak self] in
            guard let self, self.lock.withLock({ self.pending?.id == id }) else { return }
            let dragging = (0..<32).contains {
                CGEventSource.buttonState(.combinedSessionState, button: CGMouseButton(rawValue: UInt32($0))!)
            }
            self.advanceHold(flags: CGEventSource.flagsState(.combinedSessionState), dragging: dragging)
        }
    }
    func handle(_ type: CGEventType, event: CGEvent, dragging: Bool) -> Bool {
        lock.withLock {
            if type == .flagsChanged {
                guard let trigger else { held = false; return false }
                let down = event.flags.contains(trigger.flag)
                let exact = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]) == trigger.flag
                if !down { pending = nil; if open { open = false; send(.release) }; held = false }
                else if !held {
                    held = true
                    if exact && eligible && !dragging && buttons.isEmpty && keys.isEmpty { beginHold(at: event.location) }
                } else if !exact { cancel() }
                return false
            }
            let key = event.getIntegerValueField(.keyboardEventKeycode)
            if type == .keyUp && keys.remove(key) != nil { return true }
            if type == .keyDown {
                // Ownership lasts through repeats until keyUp, even after closing.
                if keys.contains(key) { return true }
                if open && key == 53 { keys.insert(key); cancel(); return true }
                cancel(); return false
            }
            let button: Int64
            switch type {
            case .leftMouseDown, .leftMouseUp, .leftMouseDragged: button = 0
            case .rightMouseDown, .rightMouseUp, .rightMouseDragged: button = 1
            default: button = event.getIntegerValueField(.mouseEventButtonNumber)
            }
            switch type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                if pending != nil { cancel(); return false }
                if open || !buttons.isEmpty {
                    buttons.insert(button)
                    if open { open = false; send(.click(event.location)) }
                    return true
                }
            case .leftMouseUp, .rightMouseUp, .otherMouseUp:
                if buttons.remove(button) != nil { return true }
            case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
                if buttons.contains(button) { return true }
                if open { send(.move(event.location)); return true }
            case .mouseMoved:
                pending?.point = event.location
                if open { send(.move(event.location)) }
            case .scrollWheel: pending = nil; return open
            default: break
            }
            return false
        }
    }
}

enum RadialTrigger: String, CaseIterable {
    case option, control, shift, command
    var title: String { switch self { case .option: return "Option ⌥"; case .control: return "Control ⌃"; case .shift: return "Shift ⇧"; case .command: return "Command ⌘" } }
    var flag: CGEventFlags { switch self { case .option: return .maskAlternate; case .control: return .maskControl; case .shift: return .maskShift; case .command: return .maskCommand } }
}
