import Carbon.HIToolbox

enum PresentationAction: String, CaseIterable {
    case mode, capture, magnifier, toolbar, nextPointer, previousPointer, sound, matchInk
    case captureRegion = "capture-region"
    case pen, rectangle, arrow, text, number, undo, redo, settings, exitPointer
    case gesture1, gesture2

    var title: String {
        switch self {
        case .mode: return "Toggle Interact"
        case .capture: return "Take Screenshot"
        case .captureRegion: return "Capture Region…"
        case .magnifier: return "Toggle Magnification"
        case .gesture1: return "Hold Gesture 1"
        case .gesture2: return "Hold Gesture 2"
        case .toolbar: return "Show / Hide Toolbar"
        case .nextPointer: return "Next Pointer"
        case .previousPointer: return "Previous Pointer"
        case .sound: return "Toggle Tap Sound"
        case .matchInk: return "Match Ink to Pointer"
        case .undo: return "Undo Annotation"
        case .redo: return "Redo Annotation"
        case .settings: return "Open Settings"
        case .exitPointer: return "Turn Pointer Off"
        default: return "\(rawValue.capitalized) Tool"
        }
    }

    var tool: DrawingTool? { DrawingTool(rawValue: rawValue) }
    var drawOnly: Bool { tool != nil || self == .undo || self == .redo }
    var gesture: HandGestureSlot? { self == .gesture1 ? .first : self == .gesture2 ? .second : nil }

}

enum ShortcutRules {
    static func isReserved(_ value: Shortcut) -> Bool {
        if value.modifiers == UInt32(cmdKey | shiftKey), value.keyCode == UInt32(kVK_ANSI_Z) { return true }
        guard value.modifiers == UInt32(cmdKey) else { return false }
        return [kVK_ANSI_Z, kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_X,
                kVK_ANSI_A, kVK_ANSI_N, kVK_ANSI_O, kVK_ANSI_S, kVK_ANSI_F, kVK_ANSI_P,
                kVK_ANSI_Comma].map(UInt32.init).contains(value.keyCode)
    }
}
