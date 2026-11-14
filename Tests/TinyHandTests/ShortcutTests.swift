import Carbon.HIToolbox
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct ShortcutTests {
    @Test func standardEditingCommandsStayReserved() {
        for modifiers in [UInt32(cmdKey), UInt32(cmdKey | shiftKey)] {
            #expect(ShortcutRules.isReserved(Shortcut(keyCode: UInt32(kVK_ANSI_Z), modifiers: modifiers, display: "Undo/Redo")))
        }
        #expect(ShortcutRules.isReserved(Shortcut(keyCode: UInt32(kVK_ANSI_Comma), modifiers: UInt32(cmdKey), display: "Settings")))
        #expect(ShortcutRules.isReserved(Shortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey), display: "Paste")))
    }

    @Test func freshAndResetPreferencesHaveNoAssignments() {
        Preferences.resetAll()
        #expect(Preferences.toggleShortcut == nil)
        #expect(Preferences.clearShortcut == nil)
        for action in PresentationAction.allCases {
            #expect(Preferences.shortcut(for: action) == nil)
            #expect(Preferences.storage.object(forKey: "shortcut.\(action.rawValue)") == nil)
            Preferences.setShortcut(custom, for: action)
        }
        Preferences.toggleShortcut = custom
        Preferences.clearShortcut = custom
        Preferences.resetAll()
        #expect(Preferences.toggleShortcut == nil)
        #expect(Preferences.clearShortcut == nil)
        for action in PresentationAction.allCases { #expect(Preferences.shortcut(for: action) == nil) }
    }

    @Test func explicitLegacyAssignmentsSurviveAndClearingRemovesStorage() {
        Preferences.resetAll()
        // The old app only stored dictionaries after an explicit assignment. Even
        // an assignment equal to a former default remains the user's choice.
        let old = ["keyCode": kVK_ANSI_H, "modifiers": controlKey | optionKey, "display": "⌃⌥H"] as [String: Any]
        Preferences.storage.set(old, forKey: "shortcut.toggle")
        Preferences.storage.set(old, forKey: "shortcut.pen")
        #expect(Preferences.toggleShortcut?.display == "⌃⌥H")
        #expect(Preferences.shortcut(for: .pen) == Preferences.toggleShortcut)
        #expect(Preferences.shortcut(for: .rectangle) == nil)
        Preferences.toggleShortcut = nil
        Preferences.setShortcut(nil, for: .pen)
        #expect(Preferences.storage.object(forKey: "shortcut.toggle") == nil)
        #expect(Preferences.storage.object(forKey: "shortcut.pen") == nil)
        #expect(Preferences.toggleShortcut == nil)
        #expect(Preferences.shortcut(for: .pen) == nil)
    }

    @Test func everyCommandSupportsAnAssignmentAndClear() {
        Preferences.resetAll()
        for action in PresentationAction.allCases {
            Preferences.setShortcut(custom, for: action)
            #expect(Preferences.shortcut(for: action) == custom)
            Preferences.setShortcut(nil, for: action)
            #expect(Preferences.shortcut(for: action) == nil)
        }
        Preferences.toggleShortcut = custom
        Preferences.clearShortcut = custom
        #expect(Preferences.toggleShortcut == custom)
        #expect(Preferences.clearShortcut == custom)
        Preferences.toggleShortcut = nil
        Preferences.clearShortcut = nil
        #expect(Preferences.toggleShortcut == nil)
        #expect(Preferences.clearShortcut == nil)
    }

    @Test func malformedAssignmentsAreUnassignedWithoutCrashing() {
        for code in [-1, 128, Int.max] {
            Preferences.storage.set(["keyCode": code, "modifiers": 0, "display": "bad"], forKey: "shortcut.pen")
            #expect(Preferences.shortcut(for: .pen) == nil)
        }
        Preferences.setShortcut(nil, for: .pen)
    }

    @Test func optionalHelpNeverAdvertisesFallbacks() {
        let none: Shortcut? = nil
        #expect(none.help("Clear Drawing") == "Clear Drawing")
        #expect(Optional(custom).help("Clear Drawing") == "Clear Drawing (⌃⌥K)")
        #expect(PresentationAction.undo.drawOnly)
        #expect(PresentationAction.redo.drawOnly)
    }

    private var custom: Shortcut {
        Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey), display: "⌃⌥K")
    }
}
