import AppKit
import Carbon.HIToolbox
import Combine
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct UsabilityFix2Tests {
    private func waitFor(_ predicate: () -> Bool) async throws {
        for _ in 0..<200 {
            if predicate() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("Settings recovery refresh did not finish")
    }

    @Test func settingsRecoversHealthyJournalWithBrokenMetadata() async throws {
        let f = try PresentationArchiveTests.Fixture(); defer { f.finish() }
        let receipt = try f.store.savePreset(name: "Healthy journal")
        try f.write(Data("{truncated".utf8), ".Presentation/Recovery/\(receipt.id).info")
        let model = PresetsSettingsModel(store: f.store)
        model.refresh()
        try await waitFor { model.recoveryCopies.count == 1 }
        #expect(model.recovery?.id == receipt.id)
        let copy = try #require(model.recoveryCopies.first)
        #expect(copy.problem == nil)
        model.reviewRestore(copy)
        try await waitFor { !model.busy }
        #expect(model.restorePlan?.receipt.id == receipt.id)
        model.restorePlan = nil
        model.undo()
        try await waitFor { !model.busy }
        #expect(try f.store.presets().isEmpty)
    }

    @Test func settingsSkipsBrokenJournalDespiteHealthyMetadata() async throws {
        let f = try PresentationArchiveTests.Fixture(); defer { f.finish() }
        let older = try f.store.savePreset(name: "Readable")
        let newest = try f.store.savePreset(name: "Broken journal")
        try f.write(Data("{truncated".utf8), ".Presentation/Recovery/\(newest.id).json")
        let model = PresetsSettingsModel(store: f.store)
        model.refresh()
        try await waitFor { model.recoveryCopies.count == 2 }
        #expect(model.recovery?.id == older.id)
        #expect(model.recoveryCopies.first { $0.id == newest.id }?.problem != nil)
        model.refresh()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(model.recovery?.id == older.id)
        // A journal can also fail after Settings has already selected it.
        try f.write(JSONEncoder().encode(newest), ".Presentation/Recovery/\(newest.id).json")
        model.refresh()
        try await waitFor { model.recovery?.id == newest.id }
        try f.write(Data("{truncated again".utf8), ".Presentation/Recovery/\(newest.id).json")
        model.undo()
        try await waitFor { model.recovery?.id == older.id }
        #expect(model.recoveryCopies.first { $0.id == newest.id }?.problem != nil)
    }

    @Test func suggestedShowsCurrentBindingsAndUpdatesWithExternalEdits() throws {
        Preferences.resetAll(); defer { Preferences.resetAll() }
        let model = SettingsModel()
        var updates = 0
        let observation = model.objectWillChange.sink { updates += 1 }
        defer { observation.cancel() }
        let custom = Shortcut(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(cmdKey | shiftKey), display: "⇧⌘B")
        Preferences.radialTrigger = .shift
        Preferences.toggleShortcut = custom
        func row(_ id: String) throws -> SuggestedShortcuts.Row { try #require(model.suggestedRows.first { $0.id == id }) }
        #expect(try row("radial").status.title == "Already set")
        #expect(try row("radial").assignment?.display == "⇧")
        #expect(try row("radial").instruction == "Hold Shift to open Quick controls")
        #expect(try row("toggle").assignment == .key(custom))
        #expect(try row("toggle").instruction == "⇧⌘B")
        let before = updates
        Preferences.radialTrigger = .control
        Preferences.toggleShortcut = nil
        #expect(updates > before)
        #expect(try row("radial").instruction == "Hold Control to open Quick controls")
        #expect(try row("toggle").status == .willAdd)
        Preferences.storage.set("legacy-unknown", forKey: "radialTrigger")
        Preferences.storage.set(["invalid": true], forKey: "shortcut.toggle")
        for id in ["radial", "toggle"] {
            #expect(try row(id).status == .alreadySet)
            #expect(try row(id).assignment == nil)
            #expect(try row(id).instruction == "Existing assignment kept")
        }
    }

    @Test func existingFavoritesRefreshArtworkNamesAndArtworkUndoInBothControls() throws {
        _ = NSApplication.shared
        Preferences.resetAll(); defer { Preferences.resetAll() }
        let fixture = try PresentationArchiveTests.Fixture(); defer { fixture.finish() }
        let original = try fixture.png(red: 0.9)
        let image = try #require(NSImage(data: original)?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let style = try CustomHands.add(image, ink: 0xaa3344, name: "Before")
        defer {
            _ = try? CustomHands.remove(style)
            HandAsset.forget(style.assetName!)
        }
        Preferences.pinnedStyles = [style, .lavender]
        let toolbar = Toolbar(); defer { toolbar.hide() }
        let overlay = OverlayController(accessibility: { false })
        let menu = MenuBarControls(overlay: overlay, perform: { _ in "" }, checkForUpdates: {})
        menu.start(); defer { menu.close() }
        toolbar.select(style); menu.refresh()
        let buttons = [try #require(toolbar.favoriteButtons[style]), try #require(menu.favoriteButtons[style])]
        let frames = buttons.map(\.frame)
        let actions = buttons.map(\.action)
        let before = try buttons.map { try #require($0.image?.tiffRepresentation) }
        try CustomHands.rename(style, name: "After rename")
        menu.refresh()
        for button in buttons {
            #expect(button.toolTip == "After rename" && button.accessibilityLabel() == "After rename")
        }
        let replacement = try #require(NSImage(data: fixture.png(red: 0.2))?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let receipt = try PointerArtworkRecovery.replace(style: style, image: replacement, directory: CustomHands.directory)
        HandAsset.forget(style.assetName!)
        Preferences.notifyPointerConfigurationChanged(); menu.refresh()
        #expect(toolbar.favoriteButtons[style] === buttons[0])
        #expect(menu.favoriteButtons[style] === buttons[1])
        for (index, button) in buttons.enumerated() {
            #expect(button.frame == frames[index] && button.action == actions[index])
            #expect(button.toolTip == "After rename" && button.accessibilityLabel() == "After rename")
            #expect(button.image?.tiffRepresentation != before[index])
        }
        try receipt.undo(); HandAsset.forget(style.assetName!)
        Preferences.notifyPointerConfigurationChanged(); menu.refresh()
        for (index, button) in buttons.enumerated() {
            #expect(button.image?.tiffRepresentation == before[index])
            #expect(button.accessibilityLabel() == "After rename")
        }
    }
}
