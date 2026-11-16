import Foundation
import CoreGraphics
import ImageIO
import Testing
@testable import TinyHand

@Suite struct PresentationArchiveTests {
    struct Fixture {
        let directory: URL
        let suite: String
        let defaults: UserDefaults
        var store: PresentationStore { PresentationStore(directory: directory, storage: defaults) }
        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("presentation-test-\(UUID())")
            suite = "com.austinpresley.presentation-test.\(UUID())"
            defaults = try #require(UserDefaults(suiteName: suite))
        }
        func finish() {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        func write(_ data: Data, _ path: String) throws {
            let url = directory.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        func read(_ path: String) throws -> Data { try Data(contentsOf: directory.appendingPathComponent(path)) }
        func durableFiles() throws -> [String: Data] {
            guard let items = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else { return [:] }
            var result: [String: Data] = [:]
            for case let url as URL in items {
                let path = String(url.resolvingSymlinksInPath().path.dropFirst(directory.resolvingSymlinksInPath().path.count + 1))
                if !path.hasPrefix(".Presentation/Staging/"), try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                    result[path] = try Data(contentsOf: url)
                }
            }
            return result
        }
        func archive() throws -> PortablePresentationArchive {
            var setup = try PresentationSetup.capture(defaults)
            setup.selectedID = "custom-fixture"
            setup.pinnedIDs = ["custom-missing", "laser", "custom-fixture"]
            setup.disabledIDs = ["glove", "custom-missing"]
            var overrides = PointerConfigurationDocument()
            try overrides.replace(PointerOverride(size: 0.08, soundEnabled: false), for: "custom-missing")
            setup.pointerOverrides = try overrides.encoded()
            let hand = CustomHand(id: "custom-fixture", name: "Fixture", ink: 0xaabbcc)
            return PortablePresentationArchive(setup: setup,
                presets: [NamedPresentationPreset(id: UUID(), name: "Lecture", setup: setup)], hands: [hand],
                artwork: ["custom-fixture.png": try png(), "Gestures/custom-fixture-first.png": try png()])
        }
        func png(width: Int = 12, height: Int = 20, red: CGFloat = 1) throws -> Data {
            let ctx = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            ctx.setFillColor(red: red, green: 0, blue: 0, alpha: 1)
            ctx.fill(CGRect(x: width / 2, y: 0, width: 2, height: height))
            ctx.fill(CGRect(x: 1, y: height / 4, width: width - 2, height: height / 2))
            let data = NSMutableData()
            let destination = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, try #require(ctx.makeImage()), nil)
            #expect(CGImageDestinationFinalize(destination))
            return data as Data
        }
    }
    struct InjectedFailure: Error {}

    @Test func importingRemovedIdentityKeepsRemovalUndoAndUnpreviewedGestures() throws {
        let f = try Fixture(); defer { f.finish() }
        var older = try f.archive()
        older.artwork["Gestures/custom-fixture-first.png"] = nil
        older.setup.disabledIDs = []
        try f.write(JSONEncoder().encode(older.hands), "hands.json")
        try f.write(try #require(older.artwork["custom-fixture.png"]), "custom-fixture.png")
        let gesture = try f.png(red: 0.5)
        try f.write(gesture, "Gestures/custom-fixture-first.png")
        let removalStore = HandRecoveryStore(directory: f.directory)
        let removed = try removalStore.remove("custom-fixture")
        let manifest = try f.read("hands.json")
        let originalFiles = try f.durableFiles()
        let originalPreferences = f.defaults.persistentDomain(forName: f.suite) ?? [:]
        let plan = try f.store.preview(older)
        #expect(!plan.preview.canApply)
        #expect(plan.preview.conflicts.contains { $0.contains("Undo Remove") })
        if plan.preview.canApply {
            // The actual Settings reload sequence from the reported reproduction.
            let imported = try f.store.apply(plan)
            try removalStore.recoverInterruptedRemovals()
            for receipt in try removalStore.restoresAwaitingPreferences() {
                try HandRestoreTransaction(store: removalStore, preferences: f.defaults).restore(receipt)
            }
            try f.store.restore(imported)
        } else {
            #expect(throws: (any Error).self) { try f.store.apply(plan) }
        }
        #expect(try f.read("hands.json") == manifest)
        #expect(!FileManager.default.fileExists(atPath: f.directory.appendingPathComponent("Gestures/custom-fixture-first.png").path))
        #expect(try removalStore.pendingRemovals() == [removed])
        #expect(try f.durableFiles() == originalFiles)
        #expect(NSDictionary(dictionary: f.defaults.persistentDomain(forName: f.suite) ?? [:]).isEqual(to: originalPreferences))
        #expect(try Data(contentsOf: removalStore.package(for: removed).appendingPathComponent("Gestures/custom-fixture-first.png")) == gesture)
        // The independent Undo Remove still restores the complete newer hand.
        try HandRestoreTransaction(store: removalStore, preferences: f.defaults).restore(removed)
        #expect(try f.read("Gestures/custom-fixture-first.png") == gesture)
    }

    @Test func preferenceEditDuringArtworkStagingRejectsWithoutReplacingAcceptedEdit() throws {
        let f = try Fixture(); defer { f.finish() }
        let archive = try f.archive(), plan = try f.store.preview(archive)
        var store = f.store
        store.writeFile = { data, url in
            if url.lastPathComponent == "custom-fixture.png" {
                DispatchQueue.main.sync { f.defaults.set(0.18, forKey: "pointerSize") }
            }
            try data.write(to: url, options: .atomic)
        }
        #expect(throws: (any Error).self) { try store.apply(plan) }
        #expect(f.defaults.double(forKey: "pointerSize") == 0.18)
        #expect(NSDictionary(dictionary: f.defaults.persistentDomain(forName: f.suite) ?? [:]).isEqual(to: ["pointerSize": 0.18]))
        #expect(try f.durableFiles().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: f.directory.appendingPathComponent("hands.json").path))
        #expect(!FileManager.default.fileExists(atPath: f.directory.appendingPathComponent("custom-fixture.png").path))
        #expect(try f.store.latestRecovery() == nil)
    }

    @Test func fileEditDuringArtworkStagingPreservesExactFilesPreferencesAndPriorRecovery() throws {
        let f = try Fixture(); defer { f.finish() }
        try f.store.savePreset(name: "Local setup")
        let archive = try f.archive()
        let existing = try #require(archive.artwork["custom-fixture.png"])
        try f.write(existing, "custom-fixture.png")
        let plan = try f.store.preview(archive)
        let changed = try f.png(red: 0.3)
        var expected = try f.durableFiles()
        expected["custom-fixture.png"] = changed
        let preferences = f.defaults.persistentDomain(forName: f.suite) ?? [:]
        let prior = try #require(try f.store.latestRecovery())
        var store = f.store
        var edited = false
        store.writeFile = { data, url in
            #expect(!Thread.isMainThread)
            if !edited {
                edited = true
                try DispatchQueue.main.sync { try f.write(changed, "custom-fixture.png") }
            }
            try data.write(to: url, options: .atomic)
        }
        #expect(throws: (any Error).self) { try store.apply(plan) }
        #expect(edited)
        #expect(try f.durableFiles() == expected)
        #expect(NSDictionary(dictionary: f.defaults.persistentDomain(forName: f.suite) ?? [:]).isEqual(to: preferences))
        #expect(try f.store.latestRecovery()?.id == prior.id)
        // A fresh preview reports the conflict instead of accepting the old bytes.
        #expect(try !f.store.preview(archive).preview.canApply)
    }

    @Test func preferenceEditAfterPreparationRejectsAtMainQueueBoundaryAndRetryKeepsEdit() throws {
        let f = try Fixture(); defer { f.finish() }
        try f.store.savePreset(name: "Local setup")
        let before = try f.durableFiles()
        let prepared = try f.store.prepareImport(f.store.preview(f.archive()))
        defer { f.store.discardImport(prepared) }
        DispatchQueue.main.sync {
            f.defaults.set(0.18, forKey: "pointerSize")
            #expect(throws: (any Error).self) { try f.store.commitImport(prepared) }
        }
        #expect(f.defaults.double(forKey: "pointerSize") == 0.18)
        #expect(try f.durableFiles() == before)
        let afterEdit = f.defaults.persistentDomain(forName: f.suite) ?? [:]
        let receipt = try f.store.apply(f.store.preview(f.archive()))
        try f.store.restore(receipt)
        #expect(NSDictionary(dictionary: f.defaults.persistentDomain(forName: f.suite) ?? [:]).isEqual(to: afterEdit))
    }

    @Test func matchingArtworkAndOmittedGestureChangesInvalidatePreparedImport() throws {
        for path in ["custom-fixture.png", "Gestures/custom-fixture-second.png", "hands.json", ".Presentation/presets.json"] {
            let f = try Fixture(); defer { f.finish() }
            let archive = try f.archive()
            try f.write(try #require(archive.artwork["custom-fixture.png"]), "custom-fixture.png")
            let prepared = try f.store.prepareImport(f.store.preview(archive))
            defer { f.store.discardImport(prepared) }
            let edit = Data("accepted local edit".utf8)
            try f.write(edit, path)
            let before = try f.durableFiles()
            #expect(throws: (any Error).self) { try DispatchQueue.main.sync { try f.store.commitImport(prepared) } }
            #expect(try f.durableFiles() == before)
            #expect(f.defaults.object(forKey: "pointerSize") == nil)
        }
    }

    @Test func removalDuringStagingKeepsExactRemovalPackageAndRequiresFreshPreview() throws {
        let f = try Fixture(); defer { f.finish() }
        var archive = try f.archive()
        archive.artwork["Gestures/custom-fixture-first.png"] = nil
        try f.write(JSONEncoder().encode(archive.hands), "hands.json")
        try f.write(try #require(archive.artwork["custom-fixture.png"]), "custom-fixture.png")
        try f.write(f.png(red: 0.4), "Gestures/custom-fixture-first.png")
        let plan = try f.store.preview(archive)
        var store = f.store
        var expected: [String: Data] = [:]
        var removed: HandRecoveryStore.Receipt?
        store.writeFile = { data, url in
            if removed == nil {
                removed = try DispatchQueue.main.sync { try HandRecoveryStore(directory: f.directory).remove("custom-fixture") }
                expected = try f.durableFiles()
            }
            try data.write(to: url, options: .atomic)
        }
        #expect(throws: (any Error).self) { try store.apply(plan) }
        #expect(try f.durableFiles() == expected)
        #expect(try HandRecoveryStore(directory: f.directory).pendingRemovals() == [try #require(removed)])
        #expect(try !f.store.preview(archive).preview.canApply)
    }

    @Test func legacyInterruptedAndCompletedRemovalPhasesKeepTheirOwnership() throws {
        let f = try Fixture(); defer { f.finish() }
        let archive = try f.archive()
        try f.write(JSONEncoder().encode(archive.hands), "hands.json")
        for (path, data) in archive.artwork { try f.write(data, path) }
        let recovery = HandRecoveryStore(directory: f.directory)
        let removed = try recovery.remove("custom-fixture")
        // Legacy receipts have this same version-1 payload and no phase marker.
        #expect(try !f.store.preview(archive).preview.canApply)
        try f.write(JSONEncoder().encode(archive.hands), "hands.json")
        #expect(try !f.store.preview(archive).preview.canApply)
        try recovery.recoverInterruptedRemovals()
        #expect(try recovery.pendingRemovals() == [removed])
        try recovery.restoreFiles(removed)
        #expect(try !f.store.preview(archive).preview.canApply)
        try recovery.completeRestore(removed)
        let before = try f.durableFiles()
        let plan = try f.store.preview(archive)
        #expect(plan.preview.canApply)
        let receipt = try f.store.apply(plan)
        try f.store.restore(receipt)
        let after = try f.durableFiles().filter { !$0.key.hasPrefix(".Presentation/") }
        #expect(after == before.filter { !$0.key.hasPrefix(".Presentation/") })
        #expect(try recovery.pendingRemovals().isEmpty)
    }

    @Test func catalogAndRecoveryPhaseChangesRejectPreparedImportWithoutConsumingRecovery() throws {
        let f = try Fixture(); defer { f.finish() }
        let other = CustomHand(id: "custom-other", name: "Other", ink: 0)
        try f.write(JSONEncoder().encode([other]), "hands.json")
        try f.write(f.png(), "custom-other.png")
        let recovery = HandRecoveryStore(directory: f.directory)
        let removed = try recovery.remove(other.id)
        var store = f.store
        store.availableIDs = ["laser", "glove"]
        let archive = try f.archive(), plan = try store.preview(archive)
        let prepared = try store.prepareImport(plan)
        defer { store.discardImport(prepared) }
        var changedCatalog = store
        changedCatalog.availableIDs = ["laser"]
        #expect(throws: (any Error).self) { try DispatchQueue.main.sync { try changedCatalog.commitImport(prepared) } }
        // Change only a recovery marker, leaving all import destinations intact.
        try Data().write(to: recovery.package(for: removed).appendingPathComponent("restoring"))
        let before = try f.durableFiles()
        #expect(throws: (any Error).self) { try DispatchQueue.main.sync { try store.commitImport(prepared) } }
        #expect(try f.durableFiles() == before)
        #expect(try recovery.pendingRemovals() == [removed])
    }

    @Test func publicationFailureRollsBackOriginalBytesAndFreshPreviewCanRetry() throws {
        let f = try Fixture(); defer { f.finish() }
        try f.write(Data("[  ]".utf8), "hands.json")
        f.defaults.set(0.18, forKey: "pointerSize")
        let before = try f.durableFiles(), preferences = f.defaults.persistentDomain(forName: f.suite) ?? [:]
        let archive = try f.archive()
        var store = f.store
        store.moveImportFile = { source, destination in
            #expect(Thread.isMainThread)
            if destination.lastPathComponent == "presets.json" { throw InjectedFailure() }
            try FileManager.default.moveItem(at: source, to: destination)
        }
        #expect(throws: (any Error).self) { try store.apply(store.preview(archive)) }
        #expect(try f.durableFiles().filter { !$0.key.hasPrefix(".Presentation/Recovery/") } == before)
        #expect(NSDictionary(dictionary: f.defaults.persistentDomain(forName: f.suite) ?? [:]).isEqual(to: preferences))
        #expect(try f.store.latestRecovery() == nil)
        let receipt = try f.store.apply(f.store.preview(archive))
        try f.store.restore(receipt)
        #expect(try f.read("hands.json") == before["hands.json"])
        #expect(NSDictionary(dictionary: f.defaults.persistentDomain(forName: f.suite) ?? [:]).isEqual(to: preferences))
    }

    @Test func stagedBytesChangedAfterPreparationCannotBePublished() throws {
        let f = try Fixture(); defer { f.finish() }
        let prepared = try f.store.prepareImport(f.store.preview(f.archive()))
        defer { f.store.discardImport(prepared) }
        let staging = try #require(FileManager.default.contentsOfDirectory(at: f.directory.appendingPathComponent(".Presentation/Staging"), includingPropertiesForKeys: nil).first)
        try Data("replaced staged bytes".utf8).write(to: staging.appendingPathComponent("custom-fixture.png"))
        #expect(throws: (any Error).self) { try DispatchQueue.main.sync { try f.store.commitImport(prepared) } }
        #expect(try f.durableFiles().isEmpty)
        #expect(f.defaults.object(forKey: "pointerSize") == nil)
    }

    @Test func separatelyPreparedImportsSerializeAndSecondCannotOverwriteFirst() throws {
        let f = try Fixture(); defer { f.finish() }
        try f.write(JSONEncoder().encode([CustomHand]()), "hands.json")
        let archive = try f.archive(), plan = try f.store.preview(archive)
        let first = try f.store.prepareImport(plan)
        defer { f.store.discardImport(first) }
        let second = try f.store.prepareImport(plan)
        defer { f.store.discardImport(second) }
        let receipt = try DispatchQueue.main.sync { try f.store.commitImport(first) }
        let files = try f.durableFiles(), preferences = f.defaults.persistentDomain(forName: f.suite) ?? [:]
        #expect(throws: (any Error).self) { try DispatchQueue.main.sync { try f.store.commitImport(second) } }
        #expect(try f.durableFiles() == files)
        #expect(NSDictionary(dictionary: f.defaults.persistentDomain(forName: f.suite) ?? [:]).isEqual(to: preferences))
        #expect(try f.store.latestRecovery()?.id == receipt.id)
        try f.store.restore(receipt)
        #expect(f.defaults.object(forKey: "pointerSize") == nil)
    }

    @Test func anotherUndoJournalDuringStagingInvalidatesImportEvenWithIdenticalPreferences() throws {
        let f = try Fixture(); defer { f.finish() }
        try f.store.savePreset(name: "Local setup")
        let preset = try #require(try f.store.presets().first)
        let prepared = try f.store.prepareImport(f.store.preview(f.archive()))
        defer { f.store.discardImport(prepared) }
        // Applying this preset changes raw defaults once, then records a no-op
        // Undo journal with the same preference values on its second application.
        _ = try DispatchQueue.main.sync { try f.store.applyPreset(preset) }
        let before = try f.durableFiles()
        #expect(throws: (any Error).self) { try DispatchQueue.main.sync { try f.store.commitImport(prepared) } }
        #expect(try f.durableFiles() == before)
        let plan = try f.store.preview(f.archive())
        let second = try f.store.prepareImport(plan)
        defer { f.store.discardImport(second) }
        let accepted = try DispatchQueue.main.sync { try f.store.applyPreset(preset) }
        let after = try f.durableFiles()
        #expect(throws: (any Error).self) { try DispatchQueue.main.sync { try f.store.commitImport(second) } }
        #expect(try f.durableFiles() == after)
        #expect(try f.store.latestRecovery()?.id == accepted.id)
    }

    @Test func roundTripIncludesRawDistinctionsMissingOverridesAndArtwork() throws {
        let f = try Fixture(); defer { f.finish() }
        let archive = try f.archive()
        let decoded = try PortablePresentationArchive.decode(archive.encoded())
        #expect(decoded == archive)
        #expect(decoded.setup.pinnedIDs == ["custom-missing", "laser", "custom-fixture"])
        #expect(decoded.setup.disabledIDs == ["glove", "custom-missing"])
        #expect(try PointerConfigurationDocument.decode(decoded.setup.pointerOverrides).pointers["custom-missing"]?.size == 0.08)
        #expect(!FileManager.default.fileExists(atPath: f.directory.path))
    }

    @Test func exportIncludesBuiltInGestureOverridesAndExcludesPrivateAndMachineState() throws {
        let f = try Fixture(); defer { f.finish() }
        f.defaults.set("private-secret", forKey: "credential")
        f.defaults.set("private-source", forKey: "source")
        f.defaults.set("/another/mac/output", forKey: "capture.folder")
        f.defaults.set(["keyCode": 12], forKey: "shortcut.toggle")
        f.defaults.set("draw", forKey: "pointerMode")
        f.defaults.set(true, forKey: "active")
        f.defaults.set(true, forKey: "launchAtLogin")
        f.defaults.set([100.0, 200.0], forKey: "toolbarPosition")
        try f.write(f.png(width: 1024, height: 1536), "Gestures/glove-first.png")
        let archive = try f.store.captureArchive()
        #expect(archive.artwork["Gestures/glove-first.png"] != nil)
        let text = try #require(String(data: archive.encoded(), encoding: .utf8))
        for excluded in ["private-secret", "private-source", "capture.folder", "shortcut.toggle", "pointerMode", "launchAtLogin", "toolbarPosition"] {
            #expect(!text.contains(excluded))
        }
    }

    @Test func importMergesWithoutReplacingExistingDataAndUndoSurvivesRestart() throws {
        let f = try Fixture(); defer { f.finish() }
        let local = CustomHand(id: "custom-local", name: "Local", ink: 0x123456)
        try f.write(JSONEncoder().encode([local]), "hands.json")
        try f.write(f.png(red: 0.5), "custom-local.png")
        try f.write(Data("unrelated".utf8), "unrelated.txt")
        f.defaults.set("draw", forKey: "pointerMode")
        f.defaults.set("shortcut", forKey: "shortcut.toggle")
        f.defaults.set("/local/output", forKey: "capture.folder")
        f.defaults.set(true, forKey: "active")
        f.defaults.set(0.5, forKey: "sound.volume")
        f.defaults.set(true, forKey: "sound.muted")
        let before = f.defaults.persistentDomain(forName: f.suite)!
        let manifest = try f.read("hands.json"), artwork = try f.read("custom-local.png")
        let archive = try f.archive(), plan = try f.store.preview(archive)
        #expect(plan.preview.canApply && plan.preview.addedHands == ["Fixture"])
        #expect(plan.preview.addedArtwork.count == 2 && plan.preview.addedPresets == ["Lecture"])
        let receipt = try f.store.apply(plan)
        #expect(try JSONDecoder().decode([CustomHand].self, from: f.read("hands.json")).count == 2)
        #expect(f.defaults.stringArray(forKey: "pinnedStyles") == archive.setup.pinnedIDs)
        #expect(f.defaults.stringArray(forKey: "disabledPointerIDs") == archive.setup.disabledIDs)
        #expect(f.defaults.string(forKey: "pointerMode") == "draw")
        #expect(f.defaults.string(forKey: "capture.folder") == "/local/output")
        #expect(f.defaults.string(forKey: "shortcut.toggle") == "shortcut")
        #expect(f.defaults.bool(forKey: "active"))
        #expect(try f.read("custom-local.png") == artwork)
        let reopened = f.store
        #expect(try reopened.latestRecovery()?.id == receipt.id)
        try reopened.restore(try #require(try reopened.latestRecovery()))
        #expect(try f.read("hands.json") == manifest)
        #expect(try f.read("custom-local.png") == artwork)
        #expect(try f.read("unrelated.txt") == Data("unrelated".utf8))
        #expect(!FileManager.default.fileExists(atPath: f.directory.appendingPathComponent("custom-fixture.png").path))
        #expect(NSDictionary(dictionary: f.defaults.persistentDomain(forName: f.suite)!).isEqual(to: before))
        #expect(try reopened.latestRecovery() == nil)
        #expect(FileManager.default.fileExists(atPath: f.directory.appendingPathComponent(".Presentation/Recovery/\(receipt.id.uuidString).json").path))
    }

    @Test func identicalImportIsSafeAndDifferentArtworkOrIdentityBlocksAllChanges() throws {
        let f = try Fixture(); defer { f.finish() }
        let archive = try f.archive()
        try f.store.apply(f.store.preview(archive))
        #expect(try f.store.preview(archive).preview.addedArtwork.isEmpty)
        var different = archive
        different.hands[0].name = "Different"
        different.artwork["custom-fixture.png"] = try f.png(red: 0.5)
        let plan = try f.store.preview(different)
        #expect(!plan.preview.canApply && plan.preview.conflicts.count == 2)
        let before = try f.read("hands.json")
        #expect(throws: (any Error).self) { try f.store.apply(plan) }
        #expect(try f.read("hands.json") == before)
        #expect(try f.read("custom-fixture.png") == archive.artwork["custom-fixture.png"])
    }

    @Test func presetNameConflictNeverOverwritesLocalPreset() throws {
        let f = try Fixture(); defer { f.finish() }
        try f.store.savePreset(name: "Lecture")
        let before = try f.store.presets()
        let plan = try f.store.preview(f.archive())
        #expect(plan.preview.conflicts.count == 1 && !plan.preview.canApply)
        #expect(throws: (any Error).self) { try f.store.apply(plan) }
        #expect(try f.store.presets() == before)
    }

    @Test func namedSaveUpdateApplyRemoveAndUndoPreserveNonvisualState() throws {
        let f = try Fixture(); defer { f.finish() }
        f.defaults.set("draw", forKey: "pointerMode")
        f.defaults.set("keys", forKey: "shortcut.clear")
        f.defaults.set(false, forKey: "active")
        f.defaults.set("/local", forKey: "capture.folder")
        f.defaults.set(0.08, forKey: "pointerSize")
        f.defaults.set(0.25, forKey: "sound.volume")
        f.defaults.set(true, forKey: "sound.muted")
        f.defaults.set(["laser", "custom-missing"], forKey: "pinnedStyles")
        try f.store.savePreset(name: "  Webinar  ")
        var preset = try #require(f.store.presets().first)
        #expect(preset.name == "Webinar")
        #expect(throws: (any Error).self) { try f.store.savePreset(name: "webinar") }
        f.defaults.set(0.15, forKey: "pointerSize")
        let apply = try f.store.applyPreset(preset)
        #expect(f.defaults.double(forKey: "pointerSize") == 0.08)
        #expect(f.defaults.double(forKey: "sound.volume") == 0.25 && f.defaults.bool(forKey: "sound.muted"))
        #expect(f.defaults.stringArray(forKey: "pinnedStyles") == ["laser", "custom-missing"])
        #expect(f.defaults.string(forKey: "pointerMode") == "draw")
        #expect(f.defaults.string(forKey: "shortcut.clear") == "keys")
        #expect(f.defaults.string(forKey: "capture.folder") == "/local")
        #expect(!f.defaults.bool(forKey: "active"))
        try f.store.restore(apply)
        #expect(f.defaults.double(forKey: "pointerSize") == 0.15)
        try f.store.savePreset(name: "Webinar", replacing: preset.id)
        preset = try #require(f.store.presets().first)
        #expect(preset.setup.settings["pointerSize"] == .number(0.15))
        let removal = try f.store.removePreset(preset.id)
        #expect(try f.store.presets().isEmpty)
        // Undo file-only operations must preserve ordinary setting edits.
        f.defaults.set(0.12, forKey: "pointerSize")
        try f.store.restore(removal)
        #expect(try f.store.presets() == [preset])
        #expect(f.defaults.double(forKey: "pointerSize") == 0.12)
    }

    @Test func failuresAfterArtworkWritesRestoreAllBytesAndAbsentPreferences() throws {
        let f = try Fixture(); defer { f.finish() }
        try f.write(JSONEncoder().encode([CustomHand]()), "hands.json")
        let before = try f.read("hands.json")
        var store = f.store
        var filesWritten = 0
        store.writeFile = { data, url in
            if url.lastPathComponent == "hands.json" { throw InjectedFailure() }
            try data.write(to: url, options: .atomic)
            filesWritten += 1
        }
        #expect(throws: (any Error).self) { try store.apply(store.preview(f.archive())) }
        #expect(filesWritten >= 2)
        #expect(try f.read("hands.json") == before)
        #expect(!FileManager.default.fileExists(atPath: f.directory.appendingPathComponent("custom-fixture.png").path))
        #expect(f.defaults.object(forKey: "pointerSize") == nil)
        #expect(try f.store.latestRecovery() == nil)
    }

    @Test func failedRollbackRetainsJournalAndCanRecoverAfterAccessIsRepaired() throws {
        let f = try Fixture(); defer { f.finish() }
        var store = f.store
        store.moveImportFile = { source, destination in
            if destination.lastPathComponent == "hands.json" {
                let artwork = f.directory.appendingPathComponent("custom-fixture.png")
                try FileManager.default.removeItem(at: artwork)
                try FileManager.default.createDirectory(at: artwork, withIntermediateDirectories: false)
                throw InjectedFailure()
            }
            try FileManager.default.moveItem(at: source, to: destination)
        }
        do {
            try store.apply(store.preview(f.archive()))
            Issue.record("Expected interrupted application")
        } catch { #expect(error.localizedDescription.contains("Recovery is retained")) }
        let receipt = try #require(try f.store.latestRecovery())
        #expect(f.defaults.object(forKey: "pointerSize") == nil)
        try FileManager.default.removeItem(at: f.directory.appendingPathComponent("custom-fixture.png"))
        try f.store.restore(receipt)
        #expect(try f.store.latestRecovery() == nil)
        #expect(!FileManager.default.fileExists(atPath: f.directory.appendingPathComponent("Gestures/custom-fixture-first.png").path))
    }

    @Test func countDimensionAndTotalSizeLimitsFailBeforeWriting() throws {
        let f = try Fixture(); defer { f.finish() }
        var archive = try f.archive()
        archive.presets = (0...100).map { NamedPresentationPreset(id: UUID(), name: "Preset \($0)", setup: archive.setup) }
        #expect(throws: (any Error).self) { try archive.validate() }
        archive.presets = []
        archive.artwork["custom-fixture.png"] = try f.png(width: 8193, height: 2)
        #expect(throws: (any Error).self) { try archive.validate() }
        let data = Data(repeating: 0, count: 8_000_000)
        archive.artwork = Dictionary(uniqueKeysWithValues: (0..<9).map { ("custom-\($0).png", data) })
        #expect(throws: (any Error).self) { try archive.validate() }
        #expect(!FileManager.default.fileExists(atPath: f.directory.path))
    }

    @Test func interruptedPartialApplicationCanRecoverAndRetry() throws {
        let f = try Fixture(); defer { f.finish() }
        let receipt = try f.store.apply(f.store.preview(f.archive()))
        // Simulate a process stopping after some files but before all preferences.
        f.defaults.removeObject(forKey: "pointerStyle")
        try FileManager.default.removeItem(at: f.directory.appendingPathComponent("custom-fixture.png"))
        try f.store.restore(try #require(try f.store.latestRecovery()))
        #expect(f.defaults.object(forKey: "pointerSize") == nil)
        #expect(!FileManager.default.fileExists(atPath: f.directory.appendingPathComponent("hands.json").path))
        #expect(try f.store.latestRecovery() == nil)
        #expect(receipt.files.count == 4)
        try f.store.apply(f.store.preview(f.archive()))
        #expect(try f.store.captureArchive().hands.count == 1)
    }

    @Test func undoRefusesLaterFileAndPreferenceEditsBeforeAnyWrite() throws {
        let f = try Fixture(); defer { f.finish() }
        let receipt = try f.store.apply(f.store.preview(f.archive()))
        let manifest = try f.read("hands.json")
        let changed = try f.png(red: 0.25)
        try f.write(changed, "custom-fixture.png")
        #expect(throws: (any Error).self) { try f.store.restore(receipt) }
        #expect(try f.read("hands.json") == manifest)
        #expect(try f.read("custom-fixture.png") == changed)
        try f.write(try #require(receipt.files.first { $0.path == "custom-fixture.png" }?.after), "custom-fixture.png")
        f.defaults.set(0.18, forKey: "pointerSize")
        #expect(throws: (any Error).self) { try f.store.restore(receipt) }
        #expect(try f.read("hands.json") == manifest)
        #expect(f.defaults.double(forKey: "pointerSize") == 0.18)
        #expect(try f.store.latestRecovery()?.id == receipt.id)
    }

    @Test func stalePreviewRejectsBothFileAndPreferenceRaces() throws {
        let f = try Fixture(); defer { f.finish() }
        let plan = try f.store.preview(f.archive())
        f.defaults.set(0.14, forKey: "pointerSize")
        #expect(throws: (any Error).self) { try f.store.apply(plan) }
        #expect(!FileManager.default.fileExists(atPath: f.directory.path))
        f.defaults.removeObject(forKey: "pointerSize")
        try f.write(try f.png(red: 0.5), "custom-fixture.png")
        #expect(throws: (any Error).self) { try f.store.apply(plan) }
        #expect(!FileManager.default.fileExists(atPath: f.directory.appendingPathComponent("hands.json").path))
    }

    @Test func noWritesWhenJournalCannotBePrepared() throws {
        let f = try Fixture(); defer { f.finish() }
        var store = f.store
        store.writeFile = { _, _ in throw InjectedFailure() }
        #expect(throws: (any Error).self) { try store.apply(store.preview(f.archive())) }
        #expect(f.defaults.object(forKey: "pointerSize") == nil)
        #expect(!FileManager.default.fileExists(atPath: f.directory.appendingPathComponent("custom-fixture.png").path))
    }

    @Test func symbolicLinksCannotRedirectArtworkManifestsOrRecovery() throws {
        let f = try Fixture(); defer { f.finish() }
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("presentation-outside-\(UUID())")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        try f.write(Data("safe".utf8), "sentinel")
        for path in ["Gestures", ".Presentation", "hands.json", "custom-fixture.png"] {
            let url = f.directory.appendingPathComponent(path)
            try FileManager.default.createSymbolicLink(at: url, withDestinationURL: outside)
            #expect(throws: (any Error).self) { _ = try f.store.preview(f.archive()) }
            try FileManager.default.removeItem(at: url)
        }
        let rootLink = outside.appendingPathComponent("root")
        try FileManager.default.createSymbolicLink(at: rootLink, withDestinationURL: f.directory)
        let linked = PresentationStore(directory: rootLink, storage: f.defaults)
        #expect(throws: (any Error).self) { _ = try linked.presets() }
        #expect(try f.read("sentinel") == Data("safe".utf8))
    }

    @Test func availableSelectionFallbackIsJournaledAndDoesNotDropMissingIDs() throws {
        let f = try Fixture(); defer { f.finish() }
        var store = f.store
        store.availableIDs = ["laser", "glove"]
        var setup = try PresentationSetup.capture(f.defaults)
        setup.selectedID = "custom-unplugged"
        setup.pinnedIDs = ["custom-unplugged", "laser"]
        let preset = NamedPresentationPreset(id: UUID(), name: "Offline", setup: setup)
        let receipt = try store.applyPreset(preset)
        #expect(f.defaults.string(forKey: "pointerStyle") == "laser")
        #expect(f.defaults.stringArray(forKey: "pinnedStyles") == setup.pinnedIDs)
        try store.restore(receipt)
        #expect(f.defaults.object(forKey: "pointerStyle") == nil)
    }

    @Test func noAvailableEnabledPointerRejectsPresetBeforeJournalOrPreferences() throws {
        let f = try Fixture(); defer { f.finish() }
        var store = f.store
        store.availableIDs = ["laser", "spotlight", "presentation"]
        var setup = try PresentationSetup.capture(f.defaults)
        setup.selectedID = "custom-missing"
        setup.disabledIDs = ["laser", "spotlight", "presentation"]
        let preset = NamedPresentationPreset(id: UUID(), name: "Offline", setup: setup)
        #expect(throws: (any Error).self) { try store.applyPreset(preset) }
        #expect(f.defaults.object(forKey: "pointerStyle") == nil)
        #expect(!FileManager.default.fileExists(atPath: f.directory.path))
    }

    @Test func canonicalHandIDsEndingInSlotNamesHaveRecoverableBaseArtwork() throws {
        let f = try Fixture(); defer { f.finish() }
        var archive = try f.archive()
        let data = archive.artwork["custom-fixture.png"]!
        archive.hands = [CustomHand(id: "custom-demo-first", name: "Suffix", ink: 0)]
        archive.artwork = ["custom-demo-first.png": data, "Gestures/custom-demo-first-second.png": data]
        let receipt = try f.store.apply(f.store.preview(archive))
        #expect(try f.store.latestRecovery()?.id == receipt.id)
        try f.store.restore(receipt)
        #expect(!FileManager.default.fileExists(atPath: f.directory.appendingPathComponent("custom-demo-first.png").path))
    }

    @Test func caseOnlyIdentityConflictsAndParentSymlinksStopBeforeMutation() throws {
        let f = try Fixture(); defer { f.finish() }
        try f.write(JSONEncoder().encode([CustomHand(id: "custom-FIXTURE", name: "Fixture", ink: 0)]), "hands.json")
        let before = try f.read("hands.json")
        let plan = try f.store.preview(f.archive())
        #expect(!plan.preview.canApply)
        #expect(throws: (any Error).self) { try f.store.apply(plan) }
        #expect(try f.read("hands.json") == before)
        let parent = f.directory.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: parent, withDestinationURL: f.directory)
        let linked = PresentationStore(directory: parent.appendingPathComponent("Nested"), storage: f.defaults)
        #expect(throws: (any Error).self) { _ = try linked.presets() }
    }

    @Test func unmeasurableHandsAndWrongBuiltInGestureCanvasAreRejected() throws {
        let f = try Fixture(); defer { f.finish() }
        var archive = try f.archive()
        archive.artwork["Gestures/glove-first.png"] = try f.png()
        #expect(throws: (any Error).self) { try archive.validate() }
        archive.artwork["Gestures/glove-first.png"] = nil
        archive.artwork["custom-fixture.png"] = try f.png(width: 2, height: 2)
        #expect(throws: (any Error).self) { try archive.validate() }
    }

    @Test func corruptionAndUnsupportedLocalPresetsArePreserved() throws {
        let f = try Fixture(); defer { f.finish() }
        let bad = Data("{\"version\":22,\"presets\":[]}".utf8)
        try f.write(bad, ".Presentation/presets.json")
        #expect(throws: (any Error).self) { try f.store.savePreset(name: "Test") }
        #expect(try f.read(".Presentation/presets.json") == bad)
        f.defaults.set(Data("corrupt".utf8), forKey: PointerConfigurationDocument.storageKey)
        #expect(throws: (any Error).self) { try PresentationSetup.capture(f.defaults) }
        #expect(f.defaults.data(forKey: PointerConfigurationDocument.storageKey) == Data("corrupt".utf8))
    }

    @Test func invalidArchiveComponentsFailBeforeCreatingAnything() throws {
        let f = try Fixture(); defer { f.finish() }
        let original = try f.archive()
        var cases: [PortablePresentationArchive] = []
        func changed(_ mutate: (inout PortablePresentationArchive) -> Void) {
            var value = original; mutate(&value); cases.append(value)
        }
        changed { $0.version = 2 }
        changed { $0.format = "other" }
        changed { $0.setup.selectedID = "../escape" }
        changed { $0.setup.pinnedIDs += ["laser"] }
        changed { $0.setup.disabledIDs += ["custom-fixture"] }
        changed { $0.setup.settings["pointerSize"] = .number(0.5) }
        changed { $0.setup.settings["showShadow"] = .number(1) }
        changed { $0.setup.settings["inkChoice"] = .string("unknown") }
        changed { $0.setup.settings["sound.volume"] = .number(-1) }
        changed { $0.setup.settings["sound.muted"] = .string("false") }
        changed { $0.setup.settings["capture.copy"] = .bool(false); $0.setup.settings["capture.save"] = .bool(false) }
        changed { $0.setup.settings["capture.folder"] = .string("/escape") }
        changed { $0.setup.settings["shortcut.toggle"] = .string("key") }
        changed { $0.setup.settings["strokeSmoothing"] = .number(1.5) }
        changed { $0.setup.settings.removeValue(forKey: "theme") }
        changed { $0.setup.pointerOverrides = Data("{\"version\":9,\"pointers\":{}}".utf8) }
        changed { $0.hands[0] = CustomHand(id: "../../evil", name: "Evil", ink: 0) }
        changed { $0.hands[0] = CustomHand(id: "custom-fixture", name: "Fixture", ink: 0xffffffff) }
        changed { $0.hands.append($0.hands[0]) }
        changed { $0.hands.append(CustomHand(id: "custom-FIXTURE", name: "Duplicate", ink: 0)) }
        changed { $0.artwork["../escape.png"] = $0.artwork["custom-fixture.png"] }
        changed { $0.artwork["/absolute.png"] = $0.artwork["custom-fixture.png"] }
        changed { $0.artwork["Gestures/custom-fixture/evil.png"] = $0.artwork["custom-fixture.png"] }
        changed { $0.artwork["custom-fixture.png"] = nil }
        changed { $0.artwork["custom-fixture.png"] = Data("not an image".utf8) }
        changed { $0.artwork["custom-fixture.png"] = Data(repeating: 0, count: 8_000_001) }
        let mismatched = try f.png(width: 15)
        changed { $0.artwork["Gestures/custom-fixture-first.png"] = mismatched }
        changed { $0.presets[0].name = "\n" }
        changed { $0.presets.append($0.presets[0]) }
        for archive in cases {
            #expect(throws: (any Error).self) { _ = try f.store.preview(archive) }
            #expect(throws: (any Error).self) { _ = try PortablePresentationArchive.decode(JSONEncoder().encode(archive)) }
        }
        #expect(!FileManager.default.fileExists(atPath: f.directory.path))
    }

    @Test func unknownFieldsAndWrongJSONTypesAreRejectedAtEveryLevel() throws {
        let f = try Fixture(); defer { f.finish() }
        let archive = try f.archive()
        let original = try #require(JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
        var cases: [[String: Any]] = []
        var value = original; value["credentials"] = "no"; cases.append(value)
        value = original; value["version"] = true; cases.append(value)
        value = original; value["artwork"] = []; cases.append(value)
        for (key, wrong) in [("showShadow", 1 as Any), ("pointerSize", true as Any), ("sound.muted", "true" as Any)] {
            value = original
            var setup = value["setup"] as! [String: Any]
            var settings = setup["settings"] as! [String: Any]; settings[key] = wrong
            setup["settings"] = settings; value["setup"] = setup; cases.append(value)
        }
        value = original; var setup = value["setup"] as! [String: Any]; setup["startup"] = true; value["setup"] = setup; cases.append(value)
        value = original; var hands = value["hands"] as! [[String: Any]]; hands[0]["path"] = "/escape"; value["hands"] = hands; cases.append(value)
        value = original; var presets = value["presets"] as! [[String: Any]]; presets[0]["shortcut"] = "no"; value["presets"] = presets; cases.append(value)
        for json in cases {
            #expect(throws: (any Error).self) { _ = try PortablePresentationArchive.decode(JSONSerialization.data(withJSONObject: json)) }
        }
    }
}
