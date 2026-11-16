import AppKit

/// The existing InputTap calls this before drawing routing. No second tap.
/// Flags and ordinary keyboard pairs always pass unchanged. Claimed mouse and
/// Escape pairs drain after dismissal, deactivation, or an eligibility change.
final class RadialInput {
    typealias HoldScheduler = (TimeInterval, @escaping () -> Void) -> Void
    enum Event { case open(CGPoint), move(CGPoint), release, click(CGPoint), cancel }
    var onEvent: ((UInt, Event) -> Void)?
    private let lock = NSLock()
    private var trigger: RadialTrigger?
    private var eligible = false
    private var held = false
    private var open = false
    static let holdDuration: TimeInterval = 0.180
    private struct Pending { let id: UInt; let deadline: TimeInterval; var point: CGPoint }
    private var pending: Pending?
    private var sequence: UInt = 0
    private var sessionID: UInt?
    private var reconciledReleases = 0
    private let clock: () -> TimeInterval
    private let nativeKeyState: (CGKeyCode) -> Bool
    private let scheduleHold: HoldScheduler
    init(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         nativeKeyState: @escaping (CGKeyCode) -> Bool = { CGEventSource.keyState(.combinedSessionState, key: $0) },
         scheduleHold: @escaping HoldScheduler = { delay, action in
             DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay,
                 execute: DispatchWorkItem(block: action))
         }) {
        self.clock = clock; self.nativeKeyState = nativeKeyState; self.scheduleHold = scheduleHold
    }
    private var buttons = Set<Int64>()
    private var keys = Set<Int64>()
    // Observation is independent of ownership. Ordinary native pairs never
    // become ours merely because a key was already held when the trigger rose.
    private var heldKeys = Set<Int64>()
    private static let modifierKeyCodes: Set<CGKeyCode> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
    private var ordinaryKeyIsDown: Bool {
        !heldKeys.isEmpty || (0..<128).contains {
            let code = CGKeyCode($0)
            return !Self.modifierKeyCodes.contains(code) && nativeKeyState(code)
        }
    }
    var needsTap: Bool { lock.withLock { (trigger != nil && eligible) || !buttons.isEmpty || !keys.isEmpty } }
    var diagnostics: [String: Any] { lock.withLock { ["open": open, "held": held, "buttons": buttons.sorted(), "keys": keys.sorted(), "heldKeys": heldKeys.sorted(), "eligible": eligible, "pending": pending != nil, "reconciledReleases": reconciledReleases] } }
    /// InputTap observes even keyboard pairs routed to another surface.
    func observeKeyboard(_ type: CGEventType, event: CGEvent) {
        guard type == .keyDown || type == .keyUp else { return }
        lock.withLock { recordKeyboard(type, event: event) }
    }
    private func recordKeyboard(_ type: CGEventType, event: CGEvent) {
        guard type == .keyDown || type == .keyUp else { return }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyDown { heldKeys.insert(key) }
        if type == .keyUp { heldKeys.remove(key) }
    }
    /// A disabled tap may miss releases. Fresh native samples cover keys held
    /// across re-enabling, without retaining an obsolete observed down.
    func resetKeyboardObservation() { lock.withLock { heldKeys.removeAll() } }
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
    var currentSessionID: UInt? { lock.withLock { sessionID } }
    /// A queued menu close may belong to a gesture older than the pending hold.
    func end(sessionID: UInt) {
        lock.withLock {
            guard self.sessionID == sessionID else { return }
            pending = nil; open = false; self.sessionID = nil
        }
    }
    func suspendForSystem(releasingButton: Int64?, key: Int64?) {
        lock.withLock {
            cancel(); eligible = false; held = false
            if let releasingButton { buttons.remove(releasingButton) }
            if let key { keys.remove(key) }
        }
    }
    private func send(_ event: Event) {
        guard let sessionID else { return }
        DispatchQueue.main.async { [weak self] in self?.onEvent?(sessionID, event) }
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
    func advanceHold(flags: CGEventFlags, dragging: Bool, now: TimeInterval? = nil, sessionID: UInt? = nil) {
        lock.withLock {
            // Recheck under the same lock as the transition. The old timer may
            // have sampled native state while a newer gesture began.
            if let sessionID, pending?.id != sessionID { return }
            reconcileRelease(flags)
            guard let pending, (now ?? clock()) >= pending.deadline else { return }
            self.pending = nil
            guard let trigger, held, eligible, !dragging, buttons.isEmpty, keys.isEmpty, !ordinaryKeyIsDown,
                  flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]) == trigger.flag else { return }
            open = true
            send(.open(pending.point))
        }
    }
    private func beginHold(at point: CGPoint) {
        sequence &+= 1
        let id = sequence
        sessionID = id
        pending = Pending(id: id, deadline: clock() + Self.holdDuration, point: point)
        scheduleHold(Self.holdDuration) { [weak self] in
            guard let self, self.lock.withLock({ self.pending?.id == id }) else { return }
            let dragging = (0..<32).contains {
                CGEventSource.buttonState(.combinedSessionState, button: CGMouseButton(rawValue: UInt32($0))!)
            }
            self.advanceHold(flags: CGEventSource.flagsState(.combinedSessionState), dragging: dragging, sessionID: id)
        }
    }
    func handle(_ type: CGEventType, event: CGEvent, dragging: Bool) -> Bool {
        lock.withLock {
            recordKeyboard(type, event: event)
            if type == .flagsChanged {
                guard let trigger else { held = false; return false }
                let down = event.flags.contains(trigger.flag)
                let exact = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]) == trigger.flag
                if !down { pending = nil; if open { open = false; send(.release) }; held = false }
                else if !held {
                    held = true
                    if exact && eligible && !dragging && buttons.isEmpty && keys.isEmpty && !ordinaryKeyIsDown { beginHold(at: event.location) }
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
