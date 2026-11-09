import Carbon.HIToolbox
import Testing
@testable import TinyHand

@Suite struct ShortcutTests {
    @Test func standardEditingCommandsStayReserved() {
        for modifiers in [UInt32(cmdKey), UInt32(cmdKey | shiftKey)] {
            #expect(ShortcutRules.isReserved(Shortcut(keyCode: UInt32(kVK_ANSI_Z), modifiers: modifiers, display: "Undo/Redo")))
        }
        #expect(ShortcutRules.isReserved(Shortcut(keyCode: UInt32(kVK_ANSI_Comma), modifiers: UInt32(cmdKey), display: "Settings")))
        #expect(ShortcutRules.isReserved(Shortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey), display: "Paste")))
    }
    @Test func defaultPresentationShortcutsAreAvailableToConfigure() {
        for action in PresentationAction.allCases { #expect(!ShortcutRules.isReserved(action.defaultShortcut)) }
        #expect(!ShortcutRules.isReserved(.toggleDefault))
        #expect(!ShortcutRules.isReserved(.clearDefault))
    }
}
