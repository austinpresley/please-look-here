import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct PointerCatalogTests {
    init() { Preferences.resetAll() }

    private func request(_ api: ControlBridge, _ operation: String, _ fields: [String: Any] = [:]) throws -> [String: Any] {
        var body = fields
        body["version"] = 1; body["operation"] = operation
        return try #require(JSONSerialization.jsonObject(with: api.handle(JSONSerialization.data(withJSONObject: body))) as? [String: Any])
    }

    @Test func defaultsPersistenceAndResetKeepPinsIndependent() throws {
        #expect(PointerCatalog.entries.allSatisfy { $0.enabled })
        let pins = Preferences.pinnedStyles
        Preferences.pointerSize = 0.12
        try PointerCatalog.setEnabled(false, for: .robot)
        #expect(!PointerCatalog.selectableStyles.contains(.robot))
        let suite = try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"])
        #expect(UserDefaults(suiteName: suite)?.stringArray(forKey: "disabledPointerIDs") == ["robot"])
        #expect(Preferences.pinnedStyles == pins)
        #expect(Preferences.pointerSize == 0.12)
        SettingsModel().resetToolbar()
        #expect(Preferences.disabledPointerIDs == ["robot"])
        try PointerCatalog.setEnabled(true, for: .robot)
        #expect(Preferences.pinnedStyles == pins)
        try PointerCatalog.setEnabled(false, for: .laser)
        Preferences.resetAll()
        #expect(PointerCatalog.entries.allSatisfy { $0.enabled })
        #expect(Preferences.toggleShortcut == nil)
    }

    @Test func disablingSelectedUsesLibraryOrderAndOneNotification() throws {
        PointerStyle.saved = .robot
        Preferences.pinnedStyles = [.laser, .robot]
        Preferences.pointerMode = .point
        var changes = 0
        let observer = NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { _ in changes += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        try PointerCatalog.setEnabled(false, for: .robot)
        #expect(PointerStyle.saved == .lavender)
        #expect(changes == 1)
        #expect(Preferences.pointerMode == .point)
        #expect(Preferences.pinnedStyles == [.laser, .robot])
        #expect(PointerCatalog.quickStyles == [.laser])
        #expect(PointerCatalog.selectableStyles.contains(.glove))
    }

    @Test func lastChoiceRejectsWithoutMutationAndUnusablePinsGetTemporaryFallback() throws {
        for style in PointerCatalog.selectableStyles where style != .laser { try PointerCatalog.setEnabled(false, for: style) }
        let before = Preferences.disabledPointerIDs
        Preferences.pinnedStyles = [.robot]
        #expect(PointerCatalog.quickStyles == [.laser])
        #expect(Preferences.pinnedStyles == [.robot])
        do {
            try PointerCatalog.setEnabled(false, for: .laser)
            Issue.record("Disabled the final available choice")
        } catch let error as PointerCatalog.Problem { #expect(error.code == "last-enabled-pointer") }
        #expect(Preferences.disabledPointerIDs == before)
        #expect(PointerStyle.saved == .laser)
    }

    @Test func disabledSelectionAndBatchRejectBeforeAnyMutation() throws {
        _ = NSApplication.shared
        let overlay = OverlayController()
        let api = ControlBridge(overlay: overlay, openSettings: { _ in }, openHandCreator: {})
        try PointerCatalog.setEnabled(false, for: .laser)
        let selected = overlay.style
        Preferences.strokeWidth = 7
        for (op, fields) in [
            ("style", ["style": "laser", "activate": true] as [String: Any]),
            ("laser", [:]),
            ("configure", ["settings": ["style": "laser", "lineWidth": 18]])
        ] {
            let response = try request(api, op, fields)
            #expect(response["ok"] as? Bool == false)
            #expect((response["error"] as? [String: Any])?["code"] as? String == "disabled-style")
            #expect(!overlay.isActive)
            #expect(overlay.style == selected)
            #expect(Preferences.strokeWidth == 7)
        }
        #expect(!overlay.pick(.laser))
        for value: Any in [1, "true", NSNull()] {
            #expect(try request(api, "enable-pointer", ["style": "laser", "enabled": value])["ok"] as? Bool == false)
        }
        #expect(try request(api, "enable-pointer", ["style": "laser", "enabled": true, "extra": true])["ok"] as? Bool == false)
        #expect(try request(api, "enable-pointer", ["style": "laser", "enabled": true])["ok"] as? Bool == true)
        #expect(try request(api, "style", ["style": "laser"])["ok"] as? Bool == true)
        let catalog = try #require(try request(api, "styles")["styles"] as? [[String: Any]])
        #expect(catalog.allSatisfy { $0["enabled"] is Bool && $0["available"] is Bool && $0["selectable"] is Bool })
    }

    @Test func customAssetLossRestorationAndSafeRecoveryIgnoreStaleRenderCache() throws {
        let image = try #require(HandAsset.load("hand_lavender")?.image)
        let custom = try CustomHands.add(image, ink: 0x123456, name: "Fixture hand")
        defer { _ = try? CustomHands.remove(custom); Preferences.resetAll() }
        let path = CustomHands.directory.appendingPathComponent(custom.rawValue + ".png")
        let bytes = try Data(contentsOf: path)
        Preferences.pinnedStyles = [custom]
        PointerStyle.saved = custom
        #expect(PointerCatalog.selectableStyles.contains(custom))
        _ = HandAsset.load(custom.rawValue)
        try PointerCatalog.setEnabled(false, for: custom)
        try FileManager.default.removeItem(at: path)
        var entry = try #require(PointerCatalog.entries.first { $0.style == custom })
        #expect(!entry.available && !entry.enabled)
        #expect(CustomHands.hand(custom.rawValue)?.ink == 0x123456)
        try PointerCatalog.setEnabled(true, for: custom)
        #expect(!PointerCatalog.selectableStyles.contains(custom))
        do { try PointerCatalog.validateSelection(custom); Issue.record("Selected missing image") }
        catch let error as PointerCatalog.Problem { #expect(error.code == "missing-asset") }
        try bytes.write(to: path)
        #expect(PointerCatalog.selectableStyles.contains(custom))
        for style in PointerCatalog.selectableStyles where style != custom { try PointerCatalog.setEnabled(false, for: style) }
        #expect(PointerStyle.saved == custom)
        try Data("broken PNG".utf8).write(to: path)
        PointerCatalog.reconcile()
        #expect(PointerStyle.saved == .lavender)
        #expect(PointerCatalog.selectableStyles == [.lavender])
        #expect(Preferences.pinnedStyles == [custom])
        try bytes.write(to: path)
        entry = try #require(PointerCatalog.entries.first { $0.style == custom })
        #expect(entry.available && entry.enabled)
        #expect(HandAsset.cachedThumbnail(custom.rawValue) != nil)
        HandAsset.forget(custom.rawValue)
        #expect(HandAsset.isAvailable(custom.rawValue))
        #expect(HandAsset.cachedThumbnail(custom.rawValue) != nil)
        #expect(PointerStyle.saved == .lavender)
        #expect(PointerCatalog.quickStyles == [custom])
    }

    @Test func removedManifestEntryDoesNotResumeSelectionWhenRestored() throws {
        let image = try #require(HandAsset.load("hand_lavender")?.image)
        let custom = try CustomHands.add(image, ink: 0x123456, name: "Return fixture")
        defer { _ = try? CustomHands.remove(custom); Preferences.resetAll() }
        let manifest = CustomHands.directory.appendingPathComponent("hands.json")
        let bytes = try Data(contentsOf: manifest)
        PointerStyle.saved = custom
        try JSONEncoder().encode(CustomHands.all.filter { $0.id != custom.rawValue }).write(to: manifest)
        CustomHands.reload()
        PointerCatalog.reconcile()
        #expect(PointerStyle.savedID == "lavender")
        try bytes.write(to: manifest)
        CustomHands.reload()
        PointerCatalog.reconcile()
        #expect(PointerCatalog.selectableStyles.contains(custom))
        #expect(PointerStyle.saved == .lavender)
        try PointerCatalog.setEnabled(false, for: custom)
        try CustomHands.remove(custom)
        try bytes.write(to: manifest)
        CustomHands.reload()
        #expect(PointerCatalog.entries.first { $0.style == custom }?.enabled == false)
    }
    @Test func cycleUsesAllEnabledChoicesWrapsAndKeepsActivationAndInteract() throws {
        _ = NSApplication.shared
        let overlay = OverlayController()
        let api = ControlBridge(overlay: overlay, openSettings: { _ in }, openHandCreator: {})
        Preferences.pinnedStyles = [.laser]
        try PointerCatalog.setEnabled(false, for: .robot)
        let choices = PointerCatalog.selectableStyles
        #expect(choices.count > PointerCatalog.quickStyles.count)
        #expect(overlay.pick(choices.last!))
        for next in choices {
            let response = try request(api, "cycle-pointer")
            #expect(response["ok"] as? Bool == true)
            #expect(overlay.style == next)
            #expect(!overlay.isActive)
            #expect(overlay.mode == .point)
        }
        #expect(try request(api, "on")["ok"] as? Bool == true)
        defer { overlay.deactivate() }
        #expect(try request(api, "cycle-pointer")["ok"] as? Bool == true)
        #expect(overlay.isActive)
        let selected = overlay.style
        for fields: [String: Any] in [["style": "robot"], ["activate": true], ["enabled": true]] {
            #expect(try request(api, "cycle-pointer", fields)["ok"] as? Bool == false)
            #expect(overlay.style == selected && overlay.isActive)
        }
    }

    @Test func nativeNextAndPreviousWrapTheFullCatalogFromUnpinnedCurrent() throws {
        _ = NSApplication.shared
        for mode in [PointerMode.point, .draw] {
            Preferences.pointerMode = mode
            let overlay = OverlayController()
            Preferences.pinnedStyles = [.laser]
            try PointerCatalog.setEnabled(false, for: .robot)
            let choices = PointerCatalog.selectableStyles
            for (index, current) in choices.enumerated() {
                #expect(overlay.pick(current))
                overlay.cyclePointer(by: 1)
                #expect(overlay.style == choices[(index + 1) % choices.count])
                #expect(overlay.pick(current))
                overlay.cyclePointer(by: -1)
                #expect(overlay.style == choices[(index - 1 + choices.count) % choices.count])
                #expect(!overlay.isActive && overlay.mode == mode)
                #expect(Preferences.pinnedStyles == [.laser])
            }
        }
    }

    @Test func backwardProtocolWrapsAndRejectsMalformedDirectionsWithoutMutation() throws {
        _ = NSApplication.shared
        Preferences.pointerMode = .point
        let overlay = OverlayController()
        let api = ControlBridge(overlay: overlay, openSettings: { _ in }, openHandCreator: {})
        Preferences.pinnedStyles = [.laser]
        try PointerCatalog.setEnabled(false, for: .robot)
        let choices = PointerCatalog.selectableStyles
        #expect(overlay.pick(choices.first!))
        for expected in choices.reversed() {
            #expect(try request(api, "cycle-pointer", ["direction": "backward"])["ok"] as? Bool == true)
            #expect(overlay.style == expected && !overlay.isActive && overlay.mode == .point)
        }
        let selected = overlay.style
        for value: Any in ["previous", "", "Forward", 1, true, NSNull(), ["backward"]] {
            let response = try request(api, "cycle-pointer", ["direction": value])
            #expect(response["ok"] as? Bool == false)
            #expect(overlay.style == selected && !overlay.isActive && overlay.mode == .point)
        }
        #expect(try request(api, "cycle-pointer", ["direction": "forward"])["ok"] as? Bool == true)
        #expect(overlay.style == choices[1])
        #expect(Preferences.pinnedStyles == [.laser])
    }

    @Test func backwardSkipsMissingAndDisabledCustomPointers() throws {
        let custom = try CustomHands.add(try #require(HandAsset.load("hand_lavender")?.image), ink: 0, name: "Backward cycle fixture")
        defer { _ = try? CustomHands.remove(custom); Preferences.resetAll() }
        #expect(try PointerCatalog.nextSelectable(after: .laser, direction: .backward) == custom)
        let path = CustomHands.directory.appendingPathComponent(custom.rawValue + ".png")
        let bytes = try Data(contentsOf: path)
        try FileManager.default.removeItem(at: path)
        #expect(try PointerCatalog.nextSelectable(after: .laser, direction: .backward) == PointerStyle.builtInHands.last!)
        try bytes.write(to: path)
        try PointerCatalog.setEnabled(false, for: custom)
        #expect(try PointerCatalog.nextSelectable(after: .laser, direction: .backward) == PointerStyle.builtInHands.last!)
        #expect(try PointerCatalog.nextSelectable(after: custom, direction: .backward) == .presentation)
    }

    @Test func cycleHandlesOutsideCurrentSingleChoiceAndEmptySetWithoutMutation() throws {
        Preferences.disabledPointerIDs = Set(PointerStyle.allCases.filter { $0 != .laser }.map(\.rawValue))
        #expect(try PointerCatalog.nextSelectable(after: .robot) == .laser)
        #expect(try PointerCatalog.nextSelectable(after: .laser) == .laser)
        #expect(try PointerCatalog.nextSelectable(after: .robot, direction: .backward) == .laser)
        #expect(try PointerCatalog.nextSelectable(after: .laser, direction: .backward) == .laser)
        Preferences.disabledPointerIDs.insert("laser")
        do { _ = try PointerCatalog.nextSelectable(after: .robot); Issue.record("Cycled an empty set") }
        catch let error as PointerCatalog.Problem { #expect(error.code == "no-enabled-pointer") }
        do { _ = try PointerCatalog.nextSelectable(after: .robot, direction: .backward); Issue.record("Cycled an empty set backward") }
        catch let error as PointerCatalog.Problem { #expect(error.code == "no-enabled-pointer") }
        #expect(Preferences.disabledPointerIDs.contains("laser"))
    }

    @Test func cycleReloadsCustomMembershipAndRecomputesEligibilityOnEveryRequest() throws {
        _ = NSApplication.shared
        let overlay = OverlayController()
        let api = ControlBridge(overlay: overlay, openSettings: { _ in }, openHandCreator: {})
        let custom = try CustomHands.add(try #require(HandAsset.load("hand_lavender")?.image), ink: 0, name: "Cycle fixture")
        defer { _ = try? CustomHands.remove(custom); Preferences.resetAll() }
        Preferences.pinnedStyles = [.lavender]
        #expect(overlay.pick(PointerStyle.builtInHands.last!))
        #expect(try request(api, "cycle-pointer")["ok"] as? Bool == true)
        #expect(overlay.style == custom)
        let path = CustomHands.directory.appendingPathComponent(custom.rawValue + ".png")
        let bytes = try Data(contentsOf: path)
        try FileManager.default.removeItem(at: path)
        #expect(try PointerCatalog.nextSelectable(after: PointerStyle.builtInHands.last!) == .laser)
        try bytes.write(to: path)
        #expect(try PointerCatalog.nextSelectable(after: PointerStyle.builtInHands.last!) == custom)
        let manifest = CustomHands.directory.appendingPathComponent("hands.json")
        let saved = try Data(contentsOf: manifest)
        try JSONEncoder().encode(CustomHands.all.filter { $0.id != custom.rawValue }).write(to: manifest)
        #expect(overlay.pick(PointerStyle.builtInHands.last!))
        #expect(try request(api, "cycle-pointer")["ok"] as? Bool == true)
        #expect(overlay.style == .laser)
        try saved.write(to: manifest)
        #expect(overlay.pick(PointerStyle.builtInHands.last!))
        #expect(try request(api, "cycle-pointer")["ok"] as? Bool == true)
        #expect(overlay.style == custom)
        try PointerCatalog.setEnabled(false, for: .laser)
        #expect(try request(api, "cycle-pointer")["ok"] as? Bool == true)
        #expect(overlay.style == .spotlight)
    }

}
