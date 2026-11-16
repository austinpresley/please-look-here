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
        try reopened.restoreFiles(saved)
        #expect(try f.contents().filter { $0.key != "hands.json" } == before.filter { $0.key != "hands.json" })
        #expect(try reopened.readManifest() == [f.other, f.hand])
        #expect(try reopened.pendingRemovals() == [saved])
        try reopened.completeRestore(saved)
        #expect(try reopened.pendingRemovals().isEmpty)
        #expect(throws: (any Error).self) { try reopened.restoreFiles(saved) }
    }

    @Test func restoredFilesRemainActionableUntilPreferencesCommit() throws {
        let f = try Fixture(); defer { f.finish() }
        let receipt = try f.store.remove(f.hand.id, state: .init(pinnedIDs: [f.hand.id], disabled: true))
        try f.store.restoreFiles(receipt)
        // Model process exit after the file transaction, before Settings writes.
        try HandRecoveryStore(directory: f.root).recoverInterruptedRemovals()
        #expect(try f.store.pendingRemovals() == [receipt])
        #expect(!FileManager.default.fileExists(atPath: f.store.package(for: receipt).appendingPathComponent("restored").path))
    }

    @Test func interruptedRestoreReplaysSettingsAfterRestartWithoutChangingOtherPointers() throws {
        let f = try Fixture(); defer { f.finish() }
        let domain = "com.austinpresley.tinyhand.recovery.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: domain))
        defer { preferences.removePersistentDomain(forName: domain) }
        var original = PointerConfigurationDocument()
        try original.patch(["size": 0.09, "sound": "quack"], for: f.hand.id)
        try original.patch(["sound": "coin"], for: "robot")
        let snapshot = try PointerRemovalConfiguration.snapshot(for: f.hand.id, in: original)
        let state = HandRecoveryStore.State(pinnedIDs: ["laser", f.hand.id, "robot"], disabled: true,
            selectedID: f.hand.id, extensions: [PointerRemovalConfiguration.receiptKey: snapshot])
        let before = try f.contents()
        let receipt = try f.store.remove(f.hand.id, state: state)
        var current = original
        try current.patch(["size": 0.2, "sound": "pew"], for: f.hand.id)
        try current.patch(["sound": "pew"], for: "robot")
        preferences.set(try current.encoded(), forKey: PointerConfigurationDocument.storageKey)
        preferences.set(["robot"], forKey: "disabledPointerIDs")
        preferences.set(["laser"], forKey: "pinnedStyles")
        preferences.set("laser", forKey: "pointerStyle")
        preferences.set(["keyCode": 7, "display": "sentinel"], forKey: "toggleShortcut")
        let settingsBefore = preferences.dictionaryRepresentation()
        var interrupted = HandRestoreTransaction(store: f.store, preferences: preferences)
        interrupted.afterFiles = { throw InjectedFailure() }
        #expect(throws: (any Error).self) { try interrupted.restore(receipt) }
        #expect(NSDictionary(dictionary: preferences.dictionaryRepresentation()).isEqual(to: settingsBefore))
        #expect(try f.store.pendingRemovals() == [receipt])
        #expect(try f.store.readManifest() == [f.other, f.hand])
        #expect(try f.contents().filter { $0.key != "hands.json" } == before.filter { $0.key != "hands.json" })
        let manifestAfterFiles = try Data(contentsOf: f.manifest)
        let restartedStore = HandRecoveryStore(directory: f.root)
        try restartedStore.recoverInterruptedRemovals()
        #expect(try restartedStore.restoresAwaitingPreferences() == [receipt])
        // Reopen the preference domain too, rather than reuse the old instance.
        let restartedPreferences = try #require(UserDefaults(suiteName: domain))
        try HandRestoreTransaction(store: restartedStore, preferences: restartedPreferences).restore(receipt)
        let restored = try PointerConfigurationDocument.load(from: restartedPreferences)
        #expect(restored.pointers[f.hand.id] == original.pointers[f.hand.id])
        #expect(restored.pointers["robot"] == current.pointers["robot"])
        #expect(restartedPreferences.stringArray(forKey: "disabledPointerIDs") == [f.hand.id, "robot"].sorted())
        #expect(restartedPreferences.stringArray(forKey: "pinnedStyles") == state.pinnedIDs)
        #expect(restartedPreferences.string(forKey: "pointerStyle") == "laser")
        #expect(NSDictionary(dictionary: restartedPreferences.dictionary(forKey: "toggleShortcut") ?? [:])
            .isEqual(to: preferences.dictionary(forKey: "toggleShortcut") ?? [:]))
        var expectedSettings = settingsBefore
        expectedSettings[PointerConfigurationDocument.storageKey] = try restored.encoded()
        expectedSettings["disabledPointerIDs"] = [f.hand.id, "robot"].sorted()
        expectedSettings["pinnedStyles"] = state.pinnedIDs
        #expect(NSDictionary(dictionary: restartedPreferences.dictionaryRepresentation()).isEqual(to: expectedSettings))
        #expect(try Data(contentsOf: f.manifest) == manifestAfterFiles)
        #expect(try restartedStore.pendingRemovals().isEmpty)
    }

    @Test func preferencePersistenceAndCompletionFailuresKeepReceiptRetryable() throws {
        for stage in ["persistence", "after-preferences", "completion"] {
            let f = try Fixture(); defer { f.finish() }
            let domain = "com.austinpresley.tinyhand.recovery.\(UUID().uuidString)"
            let preferences = try #require(UserDefaults(suiteName: domain))
            defer { preferences.removePersistentDomain(forName: domain) }
            let receipt = try f.store.remove(f.hand.id, state: .init(pinnedIDs: [f.hand.id], disabled: true))
            var store = f.store
            store.writeJournal = { data, url in
                if stage == "completion" && url.lastPathComponent == "restored" { throw InjectedFailure() }
                try data.write(to: url, options: .atomic)
            }
            var interrupted = HandRestoreTransaction(store: store, preferences: preferences)
            interrupted.persistPreferences = { _ in stage != "persistence" }
            interrupted.afterPreferences = { if stage == "after-preferences" { throw InjectedFailure() } }
            do { try interrupted.restore(receipt); Issue.record("Must report the failed commit") }
            catch {
                #expect(error.localizedDescription.contains(f.store.package(for: receipt).path))
                #expect(error.localizedDescription.contains("retry Undo"))
            }
            #expect(try f.store.pendingRemovals() == [receipt])
            #expect(try f.store.restoresAwaitingPreferences() == [receipt])
            #expect(!FileManager.default.fileExists(atPath: f.store.package(for: receipt).appendingPathComponent("restored").path))
            // Model a partial preference write surviving exit. Replay repairs
            // this hand while preserving another pointer's newer disabled state.
            preferences.set(["robot"], forKey: "disabledPointerIDs")
            preferences.set(["laser"], forKey: "pinnedStyles")
            try HandRestoreTransaction(store: f.store, preferences: preferences).restore(receipt)
            #expect(preferences.stringArray(forKey: "pinnedStyles") == [f.hand.id])
            #expect(preferences.stringArray(forKey: "disabledPointerIDs") == [f.hand.id, "robot"].sorted())
            #expect(try f.store.pendingRemovals().isEmpty)
        }
    }

    @Test func corruptRestorePayloadLeavesFilesManifestAndPreferencesUntouched() throws {
        let f = try Fixture(); defer { f.finish() }
        let domain = "com.austinpresley.tinyhand.recovery.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: domain))
        defer { preferences.removePersistentDomain(forName: domain) }
        let receipt = try f.store.remove(f.hand.id, state: .init(extensions:
            [PointerRemovalConfiguration.receiptKey: Data("damaged override".utf8)]))
        let manifest = try Data(contentsOf: f.manifest)
        let settings = preferences.dictionaryRepresentation()
        #expect(throws: (any Error).self) {
            try HandRestoreTransaction(store: f.store, preferences: preferences).restore(receipt)
        }
        #expect(try Data(contentsOf: f.manifest) == manifest)
        #expect(NSDictionary(dictionary: preferences.dictionaryRepresentation()).isEqual(to: settings))
        #expect(!FileManager.default.fileExists(atPath: f.root.appendingPathComponent(f.files[0]).path))
        #expect(!FileManager.default.fileExists(atPath: f.store.package(for: receipt).appendingPathComponent("restoring").path))
        #expect(try f.store.pendingRemovals() == [receipt])
    }

    @Test func legacyManifestPresentReceiptStillRequiresPreferenceReplay() throws {
        let f = try Fixture(); defer { f.finish() }
        let domain = "com.austinpresley.tinyhand.recovery.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: domain))
        defer { preferences.removePersistentDomain(forName: domain) }
        let before = try f.contents()
        let receipt = try f.store.remove(f.hand.id, state: .init(pinnedIDs: [f.hand.id], disabled: true))
        // Legacy versions wrote no restore intent. Manifest membership alone
        // cannot distinguish an interrupted Undo from a rolled-back removal.
        try #require(before["hands.json"]).write(to: f.manifest)
        let archive = try PointerConfigurationDocument().encoded()
        preferences.set(archive, forKey: PointerConfigurationDocument.storageKey)
        try f.store.recoverInterruptedRemovals()
        #expect(try f.store.pendingRemovals() == [receipt])
        try HandRestoreTransaction(store: f.store, preferences: preferences).restore(receipt)
        #expect(preferences.data(forKey: PointerConfigurationDocument.storageKey) == archive)
        #expect(preferences.stringArray(forKey: "pinnedStyles") == [f.hand.id])
        #expect(preferences.stringArray(forKey: "disabledPointerIDs") == [f.hand.id])
        #expect(try f.contents() == before)
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
        try f.store.restoreFiles(receipt)
        try f.store.completeRestore(receipt)
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
        #expect(throws: (any Error).self) { try store.restoreFiles(receipt) }
        #expect(try f.store.readManifest() == [f.other])
        #expect(try f.store.pendingRemovals() == [receipt])
        let collision = f.root.appendingPathComponent(f.files[0])
        try Data("new unrelated content".utf8).write(to: collision)
        #expect(throws: (any Error).self) { try f.store.restoreFiles(receipt) }
        #expect(try Data(contentsOf: collision) == Data("new unrelated content".utf8))
        try FileManager.default.removeItem(at: collision)
        try f.store.restoreFiles(receipt)
        #expect(try f.contents().filter { $0.key != "hands.json" } == before.filter { $0.key != "hands.json" })
        #expect(try f.store.readManifest() == [f.other, f.hand])
    }

    @Test func missingArtworkCanBeRemovedAndUndoDoesNotInventFiles() throws {
        let f = try Fixture(); defer { f.finish() }
        try FileManager.default.removeItem(at: f.root.appendingPathComponent(f.files[0]))
        let receipt = try f.store.remove(f.hand.id)
        #expect(receipt.files.count == 2)
        try f.store.restoreFiles(receipt)
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
    @Test func malformedReceiptKeepsValidMembershipAndBlocksAdd() throws {
        try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        try #require(ProcessInfo.processInfo.environment["TH_HANDS_DIR"] != nil)
        let image = try #require(HandAsset.load("hand_lavender")?.image)
        let custom = try CustomHands.add(image, ink: 0, name: "Manifest guard")
        let manifest = CustomHands.directory.appendingPathComponent("hands.json")
        let before = try Data(contentsOf: manifest)
        let damaged = CustomHands.directory.appendingPathComponent(".Removed/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: damaged, withIntermediateDirectories: true)
        let record = damaged.appendingPathComponent("receipt.json")
        let corrupt = Data("malformed receipt".utf8)
        try corrupt.write(to: record)
        defer {
            try? FileManager.default.removeItem(at: damaged)
            try? before.write(to: manifest)
            CustomHands.reload()
            _ = try? CustomHands.remove(custom)
        }
        CustomHands.reload()
        #expect(CustomHands.all.contains { $0.id == custom.rawValue })
        let recoveryMessage = CustomHands.recoveryMessage ?? ""
        let canonicalRecord = record.resolvingSymlinksInPath().standardizedFileURL.path
        #expect(recoveryMessage.contains(canonicalRecord), "Expected \(canonicalRecord); actual recovery message: \(recoveryMessage)")
        let filenames = try FileManager.default.contentsOfDirectory(atPath: CustomHands.directory.path).sorted()
        #expect(throws: (any Error).self) { try CustomHands.add(image, ink: 0, name: "Must reject") }
        #expect(try Data(contentsOf: manifest) == before)
        #expect(try Data(contentsOf: record) == corrupt)
        #expect(try FileManager.default.contentsOfDirectory(atPath: CustomHands.directory.path).sorted() == filenames)
    }

    @Test func newlyLoadedMembershipSurvivesMalformedReceiptAndAttemptedMutation() throws {
        try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        try #require(ProcessInfo.processInfo.environment["TH_HANDS_DIR"] != nil)
        let old = CustomHands.all
        let hand = CustomHand(id: "custom-\(UUID().uuidString)", name: "Uncached hand", ink: 0)
        let manifest = CustomHands.directory.appendingPathComponent("hands.json")
        try FileManager.default.createDirectory(at: CustomHands.directory, withIntermediateDirectories: true)
        let oldManifest = try? Data(contentsOf: manifest)
        let membership = try JSONEncoder().encode(old + [hand])
        try membership.write(to: manifest)
        let damaged = CustomHands.directory.appendingPathComponent(".Removed/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: damaged, withIntermediateDirectories: true)
        let record = damaged.appendingPathComponent("receipt.json")
        let corrupt = Data("malformed receipt".utf8)
        try corrupt.write(to: record)
        defer {
            try? FileManager.default.removeItem(at: damaged)
            if let oldManifest { try? oldManifest.write(to: manifest) }
            else { try? FileManager.default.removeItem(at: manifest) }
            CustomHands.reload()
        }
        CustomHands.reload()
        #expect(CustomHands.all == old + [hand])
        let style = try #require(PointerStyle(rawValue: hand.id))
        #expect(throws: (any Error).self) { try CustomHands.remove(style) }
        #expect(throws: (any Error).self) {
            try CustomHands.add(try #require(HandAsset.load("hand_lavender")?.image), ink: 0, name: "Must reject")
        }
        #expect(try Data(contentsOf: manifest) == membership)
        #expect(try Data(contentsOf: record) == corrupt)
    }

    @Test func corruptManifestBlocksAddEvenWithCachedMembership() throws {
        try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        try #require(ProcessInfo.processInfo.environment["TH_HANDS_DIR"] != nil)
        let image = try #require(HandAsset.load("hand_lavender")?.image)
        let custom = try CustomHands.add(image, ink: 0, name: "Corrupt manifest")
        let manifest = CustomHands.directory.appendingPathComponent("hands.json")
        let before = try Data(contentsOf: manifest)
        let corrupt = Data("invalid manifest".utf8)
        try corrupt.write(to: manifest)
        defer { try? before.write(to: manifest); CustomHands.reload(); _ = try? CustomHands.remove(custom) }
        #expect(throws: (any Error).self) { try CustomHands.add(image, ink: 0, name: "Must reject") }
        #expect(try Data(contentsOf: manifest) == corrupt)
    }

    @Test func undoRestoresTheRemovedHandsOverrideWithoutChangingOtherPointers() throws {
        try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        try #require(ProcessInfo.processInfo.environment["TH_HANDS_DIR"] != nil)
        Preferences.resetAll()
        let image = try #require(HandAsset.load("hand_lavender")?.image)
        let custom = try CustomHands.add(image, ink: 0x123456, name: "Override recovery")
        defer { _ = try? CustomHands.remove(custom); Preferences.resetAll() }
        try Preferences.updatePointer(custom.rawValue) { $0.size = 0.09; $0.sound = .quack }
        try Preferences.updatePointer("robot") { $0.sound = .coin }
        let model = SettingsModel()
        model.removeHand(custom)
        try Preferences.updatePointer(custom.rawValue) { $0.size = 0.20; $0.sound = .pew }
        model.undoHandRemoval()
        #expect(Preferences.pointerConfiguration(for: custom.rawValue).size == 0.09)
        #expect(Preferences.pointerConfiguration(for: custom.rawValue).sound == .quack)
        #expect(Preferences.pointerConfiguration(for: "robot").sound == .coin)
        try Preferences.updatePointer(custom.rawValue) { $0 = PointerOverride() }
        model.removeHand(custom)
        try Preferences.updatePointer(custom.rawValue) { $0.sound = .coin }
        model.undoHandRemoval()
        #expect(try PointerConfigurationDocument.load(from: Preferences.storage).pointers[custom.rawValue] == nil)
    }

    @Test func settingsReopenReplaysInterruptedFilesAndRetriesAfterArchiveRepair() throws {
        try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        try #require(ProcessInfo.processInfo.environment["TH_HANDS_DIR"] != nil)
        Preferences.resetAll()
        let custom = try CustomHands.add(try #require(HandAsset.load("hand_lavender")?.image), ink: 0, name: "Restart undo")
        defer { _ = try? CustomHands.remove(custom); Preferences.resetAll() }
        try Preferences.updatePointer(custom.rawValue) { $0.size = 0.09; $0.sound = .quack }
        try Preferences.updatePointer("robot") { $0.sound = .coin }
        Preferences.pinnedStyles = [.laser, custom, .robot]
        try PointerCatalog.setEnabled(false, for: custom)
        let model = SettingsModel()
        model.removeHand(custom)
        let receipt = try #require(model.removedHands.first)
        let store = HandRecoveryStore(directory: CustomHands.directory)
        try store.restoreFiles(receipt)
        // Interrupt after files. A damaged current archive blocks replay without
        // hiding the manifest entry or retiring the receipt.
        let goodArchive = try PointerConfigurationDocument.load(from: Preferences.storage).encoded()
        Preferences.storage.set(Data("damaged archive".utf8), forKey: PointerConfigurationDocument.storageKey)
        let failedReopen = SettingsModel()
        #expect(CustomHands.hand(custom.rawValue) != nil)
        #expect(failedReopen.removedHands.contains(receipt))
        #expect(failedReopen.handMessage?.contains("retry Undo") == true)
        #expect(try store.pendingRemovals().contains(receipt))
        Preferences.storage.set(goodArchive, forKey: PointerConfigurationDocument.storageKey)
        try Preferences.updatePointer(custom.rawValue) { $0.size = 0.2; $0.sound = .pew }
        try Preferences.updatePointer("robot") { $0.sound = .pew }
        Preferences.disabledPointerIDs.remove(custom.rawValue)
        let reopened = SettingsModel()
        #expect(!reopened.removedHands.contains(receipt))
        #expect(CustomHands.recoveryMessage == nil)
        #expect(Preferences.pointerConfiguration(for: custom.rawValue).size == 0.09)
        #expect(Preferences.pointerConfiguration(for: custom.rawValue).sound == .quack)
        #expect(Preferences.pointerConfiguration(for: "robot").sound == .pew)
        #expect(Preferences.disabledPointerIDs.contains(custom.rawValue))
        #expect(Preferences.pinnedStyles == [.laser, custom, .robot])
        #expect(try !store.pendingRemovals().contains(receipt))
    }

    @Test func corruptOverrideArchiveDoesNotRemoveTheHand() throws {
        try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        try #require(ProcessInfo.processInfo.environment["TH_HANDS_DIR"] != nil)
        Preferences.resetAll()
        let custom = try CustomHands.add(try #require(HandAsset.load("hand_lavender")?.image), ink: 0, name: "Archive guard")
        defer { _ = try? CustomHands.remove(custom); Preferences.resetAll() }
        Preferences.storage.set(Data("invalid archive".utf8), forKey: PointerConfigurationDocument.storageKey)
        let model = SettingsModel()
        model.removeHand(custom)
        #expect(CustomHands.hand(custom.rawValue) != nil)
        #expect(model.handMessage?.contains("removed") == false)
    }

    @Test func recoveryCannotReplaceAnotherPointersSettings() throws {
        var document = PointerConfigurationDocument()
        try document.patch(["sound": "coin"], for: "robot")
        let mismatched = try PointerRemovalConfiguration.snapshot(for: "robot", in: document)
        #expect(throws: PointerConfigurationError.self) {
            try PointerRemovalConfiguration.restoredArchive(mismatched, for: "custom-fixture", in: document)
        }
        #expect(document.pointers["robot"]?.sound == .coin)
    }

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
