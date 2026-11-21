import AppKit
import Carbon.HIToolbox
import ImageIO
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct UsabilityB2CTests {
    @Test func suggestionsFillOnlyEmptyCommandsSkipConflictsAndUndoExactStoredValues() throws {
        Preferences.resetAll()
        defer { Preferences.resetAll() }
        // Keep an intentionally unusual legacy display and an unrelated key.
        let original: [String: Any] = ["keyCode": 12, "modifiers": Int(cmdKey | optionKey), "display": "Exact legacy display"]
        Preferences.storage.set(original, forKey: "shortcut.toggle")
        Preferences.setShortcut(Shortcut(keyCode: 11, modifiers: UInt32(shiftKey), display: "⇧B"), for: .pen)
        let keys = SuggestedShortcuts.storageKeys
        let before = Dictionary(uniqueKeysWithValues: keys.compactMap { key in Preferences.storage.object(forKey: key).map { (key, $0) } })
        var assigned: [String] = []
        let (result, undo) = SuggestedShortcuts.apply(check: { SuggestedShortcuts.conflict($0, probe: { _ in true }) }) { item in
            assigned.append(item.id)
            switch item.assignment {
            case .hold(let trigger): Preferences.radialTrigger = trigger
            case .key(let key): Preferences.setShortcut(key, for: PresentationAction(rawValue: item.id)!)
            }
            return nil
        }
        #expect(assigned == ["radial", "undo"])
        #expect(result.summary == "2 added · 1 already set · 1 skipped")
        #expect(Preferences.toggleShortcut?.display == "Exact legacy display")
        #expect(Preferences.radialTrigger == .option)
        undo.restore()
        let after = Dictionary(uniqueKeysWithValues: keys.compactMap { key in Preferences.storage.object(forKey: key).map { (key, $0) } })
        #expect(NSDictionary(dictionary: before).isEqual(to: after))
    }
    @Test func suggestionsSkipAppAndRuntimeConflictsAndNeverUseVoiceOverModifiers() {
        Preferences.resetAll(); defer { Preferences.resetAll() }
        for item in SuggestedShortcuts.items {
            if case .key(let key) = item.assignment {
                #expect(key.modifiers & UInt32(controlKey | optionKey) != UInt32(controlKey | optionKey))
            }
            if case .hold(let trigger) = item.assignment { #expect(RadialTrigger.allCases.contains(trigger)) }
        }
        let toggle = SuggestedShortcuts.items[0]
        if case .key(let key) = toggle.assignment { Preferences.clearShortcut = key }
        #expect(SuggestedShortcuts.conflict(toggle, probe: { _ in true }) == "Assigned to another command")
        #expect(SuggestedShortcuts.conflict(SuggestedShortcuts.items[2], probe: { _ in false }) == "Unavailable in macOS or another app")
        #expect(SuggestedShortcuts.conflict(SuggestedShortcuts.items[3], probe: { _ in true }) == "Used by macOS or app commands")
    }
    @Test func suggestionsRecheckAtApplyAndAccountForRegistrationFailure() {
        Preferences.resetAll(); defer { Preferences.resetAll() }
        let rows = SuggestedShortcuts.rows(check: { _ in nil })
        #expect(rows.filter { $0.status == .willAdd }.count == 4)
        Preferences.radialTrigger = .shift
        var attempted: [String] = []
        let (result, undo) = SuggestedShortcuts.apply(check: { $0.id == "toggle" ? "New conflict" : nil }) { item in
            attempted.append(item.id); return "Registration failed"
        }
        #expect(result.added == 0 && result.alreadySet == 1 && result.skipped == 3)
        #expect(attempted == ["undo", "capture"])
        #expect(Preferences.radialTrigger == .shift)
        undo.restore(); #expect(Preferences.radialTrigger == .shift)
    }
    @Test func enabledSystemSymbolicKeysAreReserved() {
        let key = Shortcut(keyCode: 12, modifiers: UInt32(cmdKey | optionKey), display: "⌥⌘Q")
        let system: [String: Any] = [kHISymbolicHotKeyEnabled as String: true, kHISymbolicHotKeyCode as String: 12, kHISymbolicHotKeyModifiers as String: UInt32(cmdKey | optionKey)]
        #expect(ShortcutRules.symbolicConflict(key, hotKeys: [system]))
        var disabled = system; disabled[kHISymbolicHotKeyEnabled as String] = false
        #expect(!ShortcutRules.symbolicConflict(key, hotKeys: [disabled]))
    }
    @Test func malformedSavedAssignmentsAreOccupiedBySuggestions() {
        Preferences.resetAll(); defer { Preferences.resetAll() }
        Preferences.storage.set("legacy value", forKey: "shortcut.toggle")
        #expect(SuggestedShortcuts.rows(check: { _ in nil }).first?.status == .alreadySet)
    }
    private func practice(_ tool: DrawingTool, delay: Double, speed: CGFloat, clock: @escaping () -> Double) -> DrawingPracticeSession {
        DrawingPracticeSession(configuration: DrawingPracticeConfiguration(tool: tool, color: AnnotationColor(Ink.purple), width: 6, opacity: 1, smoothing: .medium, fadeStyle: .trail, fadeDelay: 1, trailDelay: delay, trailSpeed: speed), clock: clock)
    }
    @Test func trailPracticeErasesFromStartDuringDragWithRealDelayAndSpeed() throws {
        var now = 0.0
        let fast = practice(.pen, delay: 0.2, speed: 200, clock: { now })
        let slow = practice(.pen, delay: 1, speed: 40, clock: { now })
        for session in [fast, slow] { session.begin(at: .zero); session.extend(to: CGPoint(x: 200, y: 0)) }
        now = 0.8
        for session in [fast, slow] { session.ink.advanceTrails() }
        let fastLayer = try #require(fast.ink.layer.sublayers?.first as? CAShapeLayer)
        let slowLayer = try #require(slow.ink.layer.sublayers?.first as? CAShapeLayer)
        #expect(fast.ink.isDrawing && slow.ink.isDrawing)
        #expect(fastLayer.strokeStart > 0 && fastLayer.strokeStart < 1)
        #expect(slowLayer.strokeStart == 0)
        now = 1.2; fast.extend(to: CGPoint(x: 320, y: 0)); slow.extend(to: CGPoint(x: 320, y: 0))
        fast.ink.advanceTrails(); slow.ink.advanceTrails()
        #expect(((fast.ink.layer.sublayers?.first as? CAShapeLayer)?.strokeStart ?? 0) > ((slow.ink.layer.sublayers?.first as? CAShapeLayer)?.strokeStart ?? 0))
        fast.clear(); slow.clear()
    }
    @Test func trailPracticeArrowsStayWholeWhileDrawingThenFade() throws {
        var now = 0.0
        let arrow = practice(.arrow, delay: 0.2, speed: 600, clock: { now })
        arrow.begin(at: .zero); arrow.extend(to: CGPoint(x: 200, y: 60))
        now = 5; arrow.ink.advanceTrails()
        let layer = try #require(arrow.ink.layer.sublayers?.first as? CAShapeLayer)
        #expect(layer.strokeStart == 0 && layer.opacity == 1 && arrow.ink.isDrawing)
        arrow.end(); now = 6.3; arrow.ink.advanceTrails()
        #expect(layer.strokeStart == 0 && layer.opacity < 1 && layer.opacity > 0)
        arrow.clear()
    }
    @Test func replayUsesSelectedArrowTool() throws {
        let arrow = practice(.arrow, delay: 1, speed: 240, clock: { 0 })
        arrow.replay(in: CGRect(x: 0, y: 0, width: 480, height: 128))
        guard case .arrow = try #require(arrow.ink.document.annotations.first).shape else { Issue.record("Arrow replay must use the arrow renderer"); return }
        arrow.clear()
    }
    @Test func presetNowComparesSettingsOverridesAndFavoritesButNotRawJSONOrdering() throws {
        let f = try PresentationArchiveTests.Fixture(); defer { f.finish() }
        let current = try PresentationSetup.capture(f.defaults)
        var other = current
        #expect(current.matches(other))
        other.settings["strokeWidth"] = .number(10); #expect(!current.matches(other))
        other = current; other.quickControlFavorites.swapAt(0, 1); #expect(!current.matches(other))
        other = current; other.pinnedIDs.reverse(); #expect(!current.matches(other))
        other = current; other.selectedID = "robot"; #expect(!current.matches(other))
        other = current
        let decoded = try PointerConfigurationDocument.decode(other.pointerOverrides)
        other.pointerOverrides = try JSONEncoder().encode(decoded)
        #expect(current.matches(other))
        var changed = decoded; try changed.replace(PointerOverride(size: 0.18), for: "lavender")
        other.pointerOverrides = try changed.encoded(); #expect(!current.matches(other))
        f.defaults.set(["anything": "local"], forKey: "shortcut.toggle")
        #expect(current.matches(try .capture(f.defaults)))
    }
    @Test func backupContentsNameBothArtworkKindsAndLocalOnlyPreferences() {
        #expect(PresentationBackupContents.included == ["Presets", "Pointer, ink and sound settings", "Custom hand and gesture artwork", "Restored built-in hand artwork"])
        #expect(PresentationBackupContents.localOnly == ["Shortcuts", "Capture folder, startup and window positions"])
        #expect(!PresentationSetup.preferenceKeys.contains("radialTrigger"))
        #expect(!PresentationSetup.preferenceKeys.contains("capture.folder"))
        #expect(!PresentationSetup.preferenceKeys.contains("toolbarPosition"))
    }
    @Test func recoveryRestoreSavesCurrentStateFirstAndUndoRestoresIt() throws {
        let f = try PresentationArchiveTests.Fixture(); defer { f.finish() }
        let first = try f.store.savePreset(name: "First")
        f.defaults.set(12, forKey: "strokeWidth")
        _ = try f.store.savePreset(name: "Second")
        let currentFiles = try f.read(".Presentation/presets.json")
        let plan = try f.store.previewRestore(first)
        #expect(plan.replacedFiles == [".Presentation/presets.json"])
        let safety = try f.store.restoreCopy(plan)
        #expect(f.defaults.object(forKey: "strokeWidth") == nil)
        #expect(try f.store.presets().isEmpty)
        #expect(try f.store.recoveryCopies().count == 3)
        #expect(try f.store.latestRecovery()?.id == safety.id)
        try f.store.restore(safety)
        #expect(f.defaults.integer(forKey: "strokeWidth") == 12)
        #expect(try f.read(".Presentation/presets.json") == currentFiles)
    }
    @Test func recoveryRestoreStopsIfSafetyCopyCannotBeSavedOrReviewIsStale() throws {
        let f = try PresentationArchiveTests.Fixture(); defer { f.finish() }
        let receipt = try f.store.savePreset(name: "First")
        let plan = try f.store.previewRestore(receipt)
        var failing = f.store
        failing.writeFile = { _, _ in throw PresentationArchiveTests.InjectedFailure() }
        #expect(throws: (any Error).self) { try failing.restoreCopy(plan) }
        #expect(try f.store.presets().count == 1)
        f.defaults.set(10, forKey: "strokeWidth")
        #expect(throws: (any Error).self) { try f.store.restoreCopy(plan) }
        #expect(f.defaults.integer(forKey: "strokeWidth") == 10)
        #expect(try f.store.presets().count == 1)
    }
    @Test func renamingPresetPreservesItsSetup() throws {
        let f = try PresentationArchiveTests.Fixture(); defer { f.finish() }
        _ = try f.store.savePreset(name: "First")
        let first = try #require(f.store.presets().first)
        f.defaults.set(16, forKey: "strokeWidth")
        _ = try f.store.renamePreset(first.id, name: "Renamed")
        let renamed = try #require(f.store.presets().first)
        #expect(renamed.name == "Renamed" && renamed.id == first.id && renamed.setup == first.setup)
    }
}
