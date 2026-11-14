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
    private var buttons = Set<Int64>()
    private var keys = Set<Int64>()
    var needsTap: Bool { lock.withLock { (trigger != nil && eligible) || !buttons.isEmpty || !keys.isEmpty } }
    var diagnostics: [String: Any] { lock.withLock { ["open": open, "held": held, "buttons": buttons.sorted(), "keys": keys.sorted(), "eligible": eligible] } }
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
        }
    }
    func end() { lock.withLock { open = false } }
    private func send(_ event: Event) {
        DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
    }
    private func cancel() { if open { open = false; send(.cancel) } }
    func handle(_ type: CGEventType, event: CGEvent, dragging: Bool) -> Bool {
        lock.withLock {
            if type == .flagsChanged {
                guard let trigger else { held = false; return false }
                let down = event.flags.contains(trigger.flag)
                let exact = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]) == trigger.flag
                if !down { if open { open = false; send(.release) }; held = false }
                else if !held {
                    held = true
                    if exact && eligible && !dragging && buttons.isEmpty { open = true; send(.open(event.location)) }
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
                if open { send(.move(event.location)) }
            case .scrollWheel: return open
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
