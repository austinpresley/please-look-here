import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct UsabilityB1Tests {
    @Test func legacyPageIdentifiersRouteIntoFivePagesAndKeepToolDestinations() throws {
        #expect(SettingsSection.sidebarCases == [.pointers, .drawing, .shortcuts, .presets, .general])
        for name in ["appearance", "defaults", "pointer-defaults", "effects", "sound"] {
            let model = SettingsModel()
            model.navigate(try #require(SettingsRoute.parse(name)))
            #expect(model.section == .pointers && model.pointerInspector.isDefaults)
        }
        for section in SettingsSection.allCases {
            let model = SettingsModel(); model.section = section
            #expect(SettingsSection.sidebarCases.contains(model.section))
        }
        #expect(SettingsRoute.parse("about")?.section == .general)
        for pane in ToolSettingsPane.allCases {
            let route = try #require(SettingsRoute.parse(pane.rawValue))
            #expect(route.section == .drawing && route.tool == pane)
        }
    }

    @Test func migratingDifferentSavedPinsAndWheelAssignmentsLosesAndRemapsNeither() throws {
        let name = "com.austinpresley.tinyhand.unit.migration.\(UUID().uuidString)"
        let storage = try #require(UserDefaults(suiteName: name))
        defer { storage.removePersistentDomain(forName: name) }
        let pins = ["presentation", "laser", "robot", "lavender"]
        let wheel = ["custom-unavailable", "glove", "coral", "spotlight", "robot", "laser"]
        storage.set(pins, forKey: "pinnedStyles"); storage.set(wheel, forKey: RadialFavorites.storageKey)
        let before = storage.persistentDomain(forName: name)! as NSDictionary
        let migrated = FavoriteLibraryConfiguration.migrated(from: storage)
        #expect(migrated.toolbarIDs == pins && migrated.wheelIDs == wheel)
        #expect(before.isEqual(to: storage.persistentDomain(forName: name)!))
        storage.set(["laser"], forKey: "pinnedStyles")
        #expect(FavoriteLibraryConfiguration.migrated(from: storage).wheelIDs == wheel)
    }

    @Test func starsAndMovesHonorOneToEightPinsAndNeverChangeWheelOrEnableState() throws {
        Preferences.resetAll(); defer { Preferences.resetAll() }
        let wheel = ["glove", "laser", "spotlight", "presentation", "robot", "custom-missing"]
        Preferences.quickControlFavorites = wheel
        Preferences.disabledPointerIDs = ["robot"]
        Preferences.pinnedStyles = [.lavender]
        let model = SettingsModel()
        model.pin(.lavender); #expect(Preferences.pinnedStyles == [.lavender])
        for style in PointerStyle.allCases where style != .lavender { if Preferences.pinnedStyles.count < 8 { model.pin(style) } }
        #expect(Preferences.pinnedStyles.count == 8)
        let order = Preferences.pinnedStyles
        let extra = try #require(PointerStyle.allCases.first { !order.contains($0) })
        model.pin(extra); #expect(Preferences.pinnedStyles == order)
        model.movePin(order[0], direction: .right)
        #expect(Preferences.pinnedStyles[1] == order[0])
        model.unpin(order[0]); #expect(Preferences.pinnedStyles.count == 7)
        #expect(Preferences.quickControlFavorites == wheel)
        #expect(Preferences.disabledPointerIDs == ["robot"])
        _ = Preferences.assignQuickControlFavorite("laser", to: 0)
        #expect(Preferences.quickControlFavorites == ["laser", "glove", "spotlight", "presentation", "robot", "custom-missing"])
    }

    @Test func defaultsScopeHasASampleAndNoPointerActionsAndLibrarySelectionLeavesIt() {
        for style in [PointerStyle.lavender, .laser, .spotlight, .presentation] {
            var state = PointerInspectorState(style: style, scope: .defaults)
            #expect(state.title == "Pointer defaults" && state.preview.style == .lavender)
            #expect(state.handControls && !state.gestures && !state.pointerActions)
            state.select(style)
            #expect(state.scope == .this && state.preview.style == style && state.pointerActions)
        }
    }

    @Test func eachOverrideResetsIndependentlyAndDefaultsNeverOverwriteLocalValues() throws {
        Preferences.resetAll(); defer { Preferences.resetAll() }
        Preferences.pointerSize = 0.08; Preferences.showShadow = false; Preferences.shadowStyle = .original
        Preferences.handSound = false; Preferences.tapSound = .thock
        let original = PointerOverride(size: 0.18, shadow: true, shadowStyle: .contact, soundEnabled: true, sound: .pop)
        let resets: [(inout PointerOverride) -> Void] = [
            { $0.size = nil }, { $0.shadow = nil }, { $0.shadowStyle = nil }, { $0.soundEnabled = nil }, { $0.sound = nil }
        ]
        for (index, reset) in resets.enumerated() {
            try Preferences.updatePointer("lavender") { $0 = original }
            try Preferences.updatePointer("lavender", reset)
            let fields = try #require(PointerConfigurationDocument.load(from: Preferences.storage).pointers["lavender"])
            let present = [fields.size != nil, fields.shadow != nil, fields.shadowStyle != nil, fields.soundEnabled != nil, fields.sound != nil]
            #expect(present == (0..<5).map { $0 != index })
        }
        try Preferences.updatePointer("lavender") { $0 = original }
        Preferences.pointerSize = 0.12; Preferences.showShadow = true; Preferences.handSound = true
        let state = PointerInspectorState(style: .lavender, scope: .defaults)
        #expect(state.preview.size == 0.12)
        #expect(Preferences.pointerConfiguration(for: "lavender").size == 0.18)
        #expect(try PointerConfigurationDocument.load(from: Preferences.storage).pointers["lavender"] == original)
    }

    @Test func nonHandsKeepTheirOwnArtworkAndSizeLabelWithoutHandRows() {
        for (style, label) in [(PointerStyle.laser, "Dot size"), (.spotlight, "Aperture size"), (.presentation, "Rod thickness")] {
            let state = PointerInspectorState(style: style)
            #expect(state.sizeLabel == label && state.preview.style == style)
            #expect(!state.handControls && !state.gestures && state.pointerActions)
            #expect(pointerIcon(style) != nil)
        }
    }

    @Test func filtersIncludeDisabledAndMissingArtAndOnlyDeriveCounts() {
        let entries = [PointerCatalog.Entry(style: .laser, enabled: true, available: true),
            PointerCatalog.Entry(style: .robot, enabled: false, available: true),
            PointerCatalog.Entry(style: .glove, enabled: true, available: false)]
        var filter = PointerLibraryFilter(category: .hidden)
        #expect(filter.entries(from: entries, pinned: []).map(\.style) == [.robot, .glove])
        filter.category = .favorites
        #expect(filter.entries(from: entries, pinned: [.robot]).map(\.style) == [.robot])
        filter.query = "laser"; #expect(filter.entries(from: entries, pinned: [.robot]).isEmpty)
    }

    @Test func artworkRecoveryKeepsBytesAndRefusesUndoOverNewerEdits() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = folder.appendingPathComponent("custom-example.png")
        let old = Data("previous image".utf8); try old.write(to: target)
        let context = try #require(CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let receipt = try PointerArtworkRecovery.replace(id: "custom-example", image: #require(context.makeImage()), directory: folder)
        #expect(try Data(contentsOf: receipt.folder.appendingPathComponent("previous.png")) == old)
        try receipt.undo(); #expect(try Data(contentsOf: target) == old)
        try Data("newer edit".utf8).write(to: target)
        #expect(throws: (any Error).self) { try receipt.undo() }
    }

    @Test func restoringBuiltInArtworkUsesItsExistingAssetLookupName() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let asset = try #require(HandAsset.load("hand_lavender"))
        let receipt = try PointerArtworkRecovery.replace(style: .lavender, image: asset.image, directory: folder)
        #expect(receipt.target.lastPathComponent == "hand_lavender.png")
        #expect(FileManager.default.fileExists(atPath: receipt.target.path))
        try receipt.undo()
        #expect(!FileManager.default.fileExists(atPath: receipt.target.path))
        #expect(throws: (any Error).self) { try PointerArtworkRecovery.replace(style: .laser, image: asset.image, directory: folder) }
    }

    @Test func restoredArtworkInvalidatesTheSameStyleInPreviewAndLiveRenderer() throws {
        _ = try #require(ProcessInfo.processInfo.environment["TH_HANDS_DIR"])
        let name = "hand_lavender"
        let configuration = PointerInspectorState(style: .lavender).preview
        let view = PointerPreviewView(configuration: configuration)
        view.setFrameSize(CGSize(width: 280, height: 96))
        let live = ArmView(frame: CGRect(x: 0, y: 0, width: 800, height: 720))
        live.setStyle(.lavender); live.aim(cursor: CGPoint(x: 300, y: 500))
        func image(_ arm: ArmView) throws -> AnyObject {
            try #require(arm.layer?.sublayers?[2].sublayers?.last?.contents) as AnyObject
        }
        let oldPreview = try image(view.arm), oldLive = try image(live)
        let asset = try #require(HandAsset.load(name))
        let receipt = try PointerArtworkRecovery.replace(style: .lavender, image: asset.image, directory: CustomHands.directory)
        defer { try? receipt.undo(); HandAsset.forget(name); Preferences.notifyPointerConfigurationChanged(); view.stop() }
        HandAsset.forget(name); Preferences.notifyPointerConfigurationChanged()
        let updated = PointerInspectorState(style: .lavender).preview
        #expect(updated.artworkSignature != configuration.artworkSignature)
        view.configure(updated, tap: 0, motion: 0)
        live.aim(cursor: CGPoint(x: 300, y: 500))
        #expect(try image(view.arm) !== oldPreview)
        #expect(try image(live) !== oldLive)
    }

    @Test func customRenameKeepsIdentityAndOtherSavedValues() throws {
        let context = try #require(CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let style = try CustomHands.add(#require(context.makeImage()), ink: 0xAABBCC, name: "Original")
        defer { _ = try? CustomHands.remove(style) }
        let old = try #require(CustomHands.hand(style.rawValue))
        try CustomHands.rename(style, name: "Renamed")
        #expect(CustomHands.hand(style.rawValue)?.name == "Renamed")
        #expect(CustomHands.hand(style.rawValue)?.id == old.id && CustomHands.hand(style.rawValue)?.ink == old.ink)
    }

    @Test func compactInspectorPreviewKeepsTheHandInsideTheCanvasAtMaximumSize() throws {
        let state = PointerInspectorState(style: .lavender)
        var config = state.preview
        config.size = 0.20; config.shadow = false
        let view = PointerPreviewView(configuration: config)
        view.setFrameSize(CGSize(width: 280, height: 96))
        view.arm.aim(cursor: CGPoint(x: 140, y: 69.12))
        let group = try #require(view.arm.layer?.sublayers?[2])
        let hand = try #require(group.sublayers?.last)
        let asset = try #require(HandAsset.load("hand_lavender"))
        // The renderer layer retains transparent source-image margins. Measure
        // the catalog's alpha bounds, which are the pixels a person can see.
        let artwork = CGRect(x: hand.bounds.width * asset.handMinX, y: 0,
            width: hand.bounds.width * (asset.handMaxX - asset.handMinX), height: hand.bounds.height)
        let visible = hand.convert(artwork, to: view.arm.layer)
        #expect(visible.minY >= 0 && visible.maxY <= 96, "Hand frame: \(visible)")
        #expect(visible.minX >= 0 && visible.maxX <= 280)
        view.stop()
    }

    @Test func productGlyphsAreTemplateImagesAndDistinct() throws {
        let wheel = UsabilityGlyph.wheel.image, library = UsabilityGlyph.library.image
        #expect(wheel.isTemplate && library.isTemplate)
        #expect(wheel.size == NSSize(width: 24, height: 24))
        #expect(wheel.tiffRepresentation != library.tiffRepresentation)
    }
}
