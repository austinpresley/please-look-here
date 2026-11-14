import AppKit

/// Runs under InputTap's lock. A dismissing press belongs to the controls until
/// its matching release, even if the pointer is turned off in the meantime.
final class ControlInput {
    private var open = false
    private var nativeMenu = false
    private var regions: [CGRect] = []
    private var buttons = Set<Int64>()
    private var keys = Set<Int64>()
    private var statusButtons: [Int64: Bool] = [:]
    var needsTap: Bool { open || !buttons.isEmpty || !keys.isEmpty }
    var diagnostics: [String: Any] { ["open": open, "nativeMenu": nativeMenu, "buttons": buttons.sorted(), "keys": keys.sorted()] }

    func configure(open: Bool, nativeMenu: Bool, regions: [CGRect]) {
        self.open = open; self.nativeMenu = nativeMenu; self.regions = regions
        if !open { statusButtons.removeAll() }
    }
    func needsMenuRegions(_ type: CGEventType) -> Bool {
        open && nativeMenu && [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type)
    }
    func handle(_ type: CGEventType, event: CGEvent, menuRegions: [CGRect]? = nil) -> (consume: Bool, dismiss: Bool, statusClick: Bool?) {
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyDown, keys.contains(key) { return (true, false, nil) }
        if type == .keyUp, keys.remove(key) != nil { return (true, false, nil) }
        let button: Int64
        switch type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged: button = 0
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged: button = 1
        default: button = event.getIntegerValueField(.mouseEventButtonNumber)
        }
        switch type {
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if buttons.remove(button) != nil { return (true, false, statusButtons.removeValue(forKey: button)) }
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            if buttons.contains(button) { return (true, false, nil) }
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            if buttons.contains(button) { return (true, false, nil) }
        default: break
        }
        guard open else { return (false, false, nil) }
        if [.leftMouseDown, .rightMouseDown].contains(type), regions.first?.contains(event.location) == true {
            buttons.insert(button)
            statusButtons[button] = button == 1 || event.flags.contains(.maskControl)
            return (true, false, nil)
        }
        if nativeMenu {
            // Native menus handle their own keyboard and control clicks. Their
            // conventional outside-click replay must not reach a presentation.
            if let menuRegions, [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type),
               !(regions + menuRegions).contains(where: { $0.contains(event.location) }) {
                buttons.insert(button)
                return (true, true, nil)
            }
            return (false, false, nil)
        }
        if type == .keyDown, key == 53 { keys.insert(key); return (true, true, nil) }
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type),
           !regions.contains(where: { $0.contains(event.location) }) {
            buttons.insert(button)
            return (true, true, nil)
        }
        return (false, false, nil)
    }
}
