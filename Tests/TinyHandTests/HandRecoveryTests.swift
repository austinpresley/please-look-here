import Foundation
import Testing
@testable import TinyHand

@Suite struct HandRecoveryTests {
    private struct Fixture {
        let root: URL
        let hand = CustomHand(id: "custom-fixture", name: "Fixture", ink: 0x123456)
        let other = CustomHand(id: "custom-other", name: "Other", ink: 0x654321)
        var store: HandRecoveryStore { HandRecoveryStore(directory: root) }
        var manifest: URL { root.appendingPathComponent("hands.json") }
        var files: [String] { ["custom-fixture.png", "Gestures/custom-fixture-first.png", "Gestures/custom-fixture-second.png"] }
        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("hand-recovery-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root.appendingPathComponent("Gestures"), withIntermediateDirectories: true)
            try JSONEncoder().encode([other, hand]).write(to: manifest)
            for name in files + ["custom-other.png", "Gestures/custom-other-first.png"] {
                try Data(name.utf8).write(to: root.appendingPathComponent(name))
            }
        }
        func finish() { try? FileManager.default.removeItem(at: root) }
        func contents() throws -> [String: Data] {
            try Dictionary(uniqueKeysWithValues: (files + ["hands.json", "custom-other.png", "Gestures/custom-other-first.png"]).map {
                ($0, try Data(contentsOf: root.appendingPathComponent($0)))
            })
        }
    }
    private struct InjectedFailure: Error {}

    @Test func removalAndPersistedUndoIncludeAllOwnedFilesAndState() throws {
        let f = try Fixture(); defer { f.finish() }
        let before = try f.contents()
        let state = HandRecoveryStore.State(pinnedIDs: ["laser", f.hand.id], disabled: true, selectedID: "laser",
            extensions: ["pointer-overrides": Data("future settings".utf8)])
        let receipt = try f.store.remove(f.hand.id, state: state)
        #expect(try f.store.readManifest() == [f.other])
        for relative in f.files {
            #expect(!FileManager.default.fileExists(atPath: f.root.appendingPathComponent(relative).path))
            #expect(try Data(contentsOf: f.store.package(for: receipt).appendingPathComponent(relative)) == before[relative])
        }
        let reopened = HandRecoveryStore(directory: f.root)
        let saved = try #require(reopened.pendingRemovals().first)
        #expect(saved == receipt && saved.state == state)
        try reopened.restore(saved)
        #expect(try f.contents().filter { $0.key != "hands.json" } == before.filter { $0.key != "hands.json" })
        #expect(try reopened.readManifest() == [f.other, f.hand])
        #expect(try reopened.pendingRemovals().isEmpty)
        #expect(throws: (any Error).self) { try reopened.restore(saved) }
    }

    @Test func manifestFailureRollsBackArtworkAndGesturesByteForByte() throws {
        let f = try Fixture(); defer { f.finish() }
        let before = try f.contents()
        var store = f.store
        store.writeManifest = { _, _ in throw InjectedFailure() }
        #expect(throws: (any Error).self) { try store.remove(f.hand.id) }
        #expect(try f.contents() == before)
        #expect(try f.store.pendingRemovals().isEmpty)
    }

    @Test func errorAfterFirstFileRemovalRestoresLibraryAndReportsRecovery() throws {
        let f = try Fixture(); defer { f.finish() }
        let before = try f.contents()
        var store = f.store
        var count = 0
        store.removeFile = { url in
            count += 1
            if count == 2 { throw InjectedFailure() }
            try FileManager.default.removeItem(at: url)
        }
        do { _ = try store.remove(f.hand.id); Issue.record("Removal should fail") }
        catch { #expect(error.localizedDescription.contains("library was restored")) }
        #expect(count == 2)
        #expect(try f.contents() == before)
    }

    @Test func interruptedRemovalRepairsMissingFilesBeforeLoadingManifest() throws {
        let f = try Fixture(); defer { f.finish() }
        let before = try f.contents()
        let receipt = try f.store.remove(f.hand.id)
        // Model exit after deleting assets but before the manifest commit.
        try #require(before["hands.json"]).write(to: f.manifest)
        try HandRecoveryStore(directory: f.root).recoverInterruptedRemovals()
        #expect(try f.contents() == before)
        // A resolved journal cannot recreate artwork intentionally removed later.
        try FileManager.default.removeItem(at: f.root.appendingPathComponent(f.files[1]))
        try f.store.recoverInterruptedRemovals()
        #expect(!FileManager.default.fileExists(atPath: f.root.appendingPathComponent(f.files[1]).path))
        #expect(FileManager.default.fileExists(atPath: f.store.package(for: receipt).path))
    }

    @Test func failedUndoKeepsRecoveryAndCanBeRetriedWithoutOverwritingConflicts() throws {
        let f = try Fixture(); defer { f.finish() }
        let before = try f.contents()
        let receipt = try f.store.remove(f.hand.id)
        var store = f.store
        store.writeManifest = { _, _ in throw InjectedFailure() }
        #expect(throws: (any Error).self) { try store.restore(receipt) }
        #expect(try f.store.readManifest() == [f.other])
        #expect(try f.store.pendingRemovals() == [receipt])
        let collision = f.root.appendingPathComponent(f.files[0])
        try Data("new unrelated content".utf8).write(to: collision)
        #expect(throws: (any Error).self) { try f.store.restore(receipt) }
        #expect(try Data(contentsOf: collision) == Data("new unrelated content".utf8))
        try FileManager.default.removeItem(at: collision)
        try f.store.restore(receipt)
        #expect(try f.contents().filter { $0.key != "hands.json" } == before.filter { $0.key != "hands.json" })
        #expect(try f.store.readManifest() == [f.other, f.hand])
    }

    @Test func missingArtworkCanBeRemovedAndUndoDoesNotInventFiles() throws {
        let f = try Fixture(); defer { f.finish() }
        try FileManager.default.removeItem(at: f.root.appendingPathComponent(f.files[0]))
        let receipt = try f.store.remove(f.hand.id)
        #expect(receipt.files.count == 2)
        try f.store.restore(receipt)
        #expect(try f.store.readManifest() == [f.other, f.hand])
        #expect(!FileManager.default.fileExists(atPath: f.root.appendingPathComponent(f.files[0]).path))
    }

    @Test func invalidManifestAndSymlinkArtworkNeverRemoveOriginals() throws {
        let f = try Fixture(); defer { f.finish() }
        let before = try f.contents()
        let invalid = CustomHand(id: "custom-../../outside", name: "Unsafe", ink: 0)
        try JSONEncoder().encode([f.hand, invalid]).write(to: f.manifest)
        #expect(throws: (any Error).self) { try f.store.remove(f.hand.id) }
        try #require(before["hands.json"]).write(to: f.manifest)
        let target = f.root.appendingPathComponent("custom-other.png")
        let link = f.root.appendingPathComponent(f.files[0])
        try FileManager.default.removeItem(at: link)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(throws: (any Error).self) { try f.store.remove(f.hand.id) }
        #expect(try Data(contentsOf: target) == before["custom-other.png"])
        #expect(try f.store.readManifest() == [f.other, f.hand])
    }
}

@Suite(.serialized) @MainActor struct HandRemovalSettingsTests {
    @Test func settingsUndoRestoresDisabledStatePinsAndGestureFiles() throws {
        try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        try #require(ProcessInfo.processInfo.environment["TH_HANDS_DIR"] != nil)
        Preferences.resetAll()
        let image = try #require(HandAsset.load("hand_lavender")?.image)
        let custom = try CustomHands.add(image, ink: 0x123456, name: "Undo fixture")
        defer { _ = try? CustomHands.remove(custom); Preferences.resetAll() }
        let gesture = HandGestureCatalog.url(for: .first, style: custom)
        try FileManager.default.createDirectory(at: gesture.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("gesture fixture".utf8).write(to: gesture)
        Preferences.pinnedStyles = [.laser, custom, .robot]
        try PointerCatalog.setEnabled(false, for: custom)
        let model = SettingsModel()
        model.removeHand(custom)
        #expect(CustomHands.hand(custom.rawValue) == nil)
        #expect(Preferences.pinnedStyles == [.laser, .robot])
        #expect(model.removedHands.first?.hand.id == custom.rawValue)
        Preferences.disabledPointerIDs.remove(custom.rawValue)
        model.undoHandRemoval()
        #expect(CustomHands.hand(custom.rawValue)?.name == "Undo fixture")
        #expect(Preferences.disabledPointerIDs.contains(custom.rawValue))
        #expect(Preferences.pinnedStyles == [.laser, custom, .robot])
        #expect(try Data(contentsOf: gesture) == Data("gesture fixture".utf8))
        #expect(model.handMessage?.contains("restored") == true)
        // Sole-pin fallback and a newly created model exercise persisted Settings Undo.
        Preferences.pinnedStyles = [custom]
        model.removeHand(custom)
        #expect(Preferences.pinnedStyles == PointerStyle.defaultPinned)
        let reopened = SettingsModel()
        reopened.undoHandRemoval()
        #expect(Preferences.pinnedStyles == [custom])
        #expect(Preferences.disabledPointerIDs.contains(custom.rawValue))
        #expect(PointerStyle.saved != custom)
    }
}
