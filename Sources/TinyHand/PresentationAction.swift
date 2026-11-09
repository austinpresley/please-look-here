import Carbon.HIToolbox

enum PresentationAction: String, CaseIterable {
    case mode, capture, toolbar, nextPointer, previousPointer, sound, matchInk
    case pen, rectangle, arrow, text, number

    var title: String {
        switch self {
        case .mode: return "Switch Point / Draw"
        case .capture: return "Take Screenshot"
        case .toolbar: return "Show / Hide Toolbar"
        case .nextPointer: return "Next Pointer"
        case .previousPointer: return "Previous Pointer"
        case .sound: return "Toggle Tap Sound"
        case .matchInk: return "Match Ink to Pointer"
        default: return "\(rawValue.capitalized) Tool"
        }
    }

    var tool: DrawingTool? { DrawingTool(rawValue: rawValue) }
    var drawOnly: Bool { tool != nil }
    var defaultShortcut: Shortcut {
        let modified = UInt32(controlKey | optionKey)
        let keys: [PresentationAction: (Int, String)] = [
            .mode: (kVK_ANSI_D, "D"), .capture: (kVK_ANSI_S, "S"), .toolbar: (kVK_ANSI_T, "T"),
            .nextPointer: (kVK_RightArrow, "→"), .previousPointer: (kVK_LeftArrow, "←"),
            .sound: (kVK_ANSI_M, "M"), .matchInk: (kVK_ANSI_A, "A"), .pen: (kVK_ANSI_F, "F"),
            .rectangle: (kVK_ANSI_R, "R"), .arrow: (kVK_ANSI_A, "A"), .text: (kVK_ANSI_T, "T"), .number: (kVK_ANSI_N, "N")
        ]
        let key = keys[self]!
        return Shortcut(keyCode: UInt32(key.0), modifiers: drawOnly ? 0 : modified, display: (drawOnly ? "" : "⌃⌥") + key.1)
    }
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
