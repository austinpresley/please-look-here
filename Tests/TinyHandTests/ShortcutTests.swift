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

    @Test func oneConflictKeepsUnrelatedCommandsRegisteredAndRetriesOnlyTheFailure() {
        var attempted: [String] = [], removed: [UInt32] = []
        var conflicting = true
        var next: UInt32 = 0
        let keys = HotKeyBindings(register: { binding in
            attempted.append(binding.command)
            if binding.command == "capture" && conflicting { return nil }
            next += 1; return next
        }, unregister: { removed.append($0) })
        let bindings = ["toggle", "capture", "nextPointer"].enumerated().map { index, command in
            HotKeyBindings.Binding(command, shortcut: Shortcut(keyCode: UInt32(index), modifiers: 2048, display: "⌥\(index)"), press: {})
        }
        #expect(!keys.update(bindings))
        #expect(keys.count == 2 && keys.failures == ["capture": bindings[1].shortcut])
        #expect(removed.isEmpty)
        attempted.removeAll()
        #expect(!keys.update(bindings))
        #expect(attempted == ["capture"] && removed.isEmpty)
        // Opening Settings suspends context-scoped commands, but keeps their conflict visible.
        let saved = Dictionary(uniqueKeysWithValues: bindings.map { ($0.command, $0.shortcut) })
        _ = keys.update([bindings[0]], assignments: saved)
        #expect(keys.failures["capture"] == bindings[1].shortcut)
        conflicting = false; attempted.removeAll(); removed.removeAll()
        #expect(keys.update(bindings))
        #expect(attempted == ["capture", "nextPointer"])
        #expect(keys.count == 3 && keys.failures.isEmpty && removed.isEmpty)
    }

    @Test func rejectedReplacementCanRestoreExactAssignmentWithoutDroppingOtherKeys() {
        var next: UInt32 = 0, removed: [UInt32] = []
        let original = custom
        let rejected = Shortcut(keyCode: 7, modifiers: 2048, display: "Exact saved display")
        let keys = HotKeyBindings(register: { binding in
            guard binding.shortcut != rejected else { return nil }
            next += 1; return next
        }, unregister: { removed.append($0) })
        let toggle = HotKeyBindings.Binding("toggle", shortcut: original, press: {})
        let clear = HotKeyBindings.Binding("clear", shortcut: Shortcut(keyCode: 8, modifiers: 2048, display: "⌥C"), press: {})
        #expect(keys.update([toggle, clear]))
        #expect(!keys.update([.init("toggle", shortcut: rejected, press: {}), clear]))
        #expect(removed == [1] && keys.count == 1)
        #expect(keys.update([toggle, clear]))
        #expect(keys.count == 2 && removed == [1] && keys.failures.isEmpty)
        // Gesture artwork identity invalidates only that registration.
        #expect(keys.update([.init("toggle", identity: "other-hand", shortcut: original, press: {}), clear]))
        #expect(removed == [1, 3])
    }

    private var custom: Shortcut {
        Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey), display: "⌃⌥K")
    }
}
