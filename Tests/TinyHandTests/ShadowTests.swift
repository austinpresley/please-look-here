import AppKit
import Metal
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct ShadowTests {
    @Test func stylePersistsIndependentlyOfVisibilityAndResetPreservesTheOriginalDefault() {
        let previous = Preferences.storage.object(forKey: "shadowStyle")
        let visible = Preferences.storage.object(forKey: "showShadow")
        defer {
            Preferences.storage.set(previous, forKey: "shadowStyle")
            Preferences.storage.set(visible, forKey: "showShadow")
        }
        Preferences.storage.removeObject(forKey: "shadowStyle")
        #expect(Preferences.shadowStyle == .original)
        Preferences.shadowStyle = .contact
        Preferences.showShadow = false
        #expect(Preferences.storage.string(forKey: "shadowStyle") == "contact")
        #expect(Preferences.shadowStyle == .contact)
        Preferences.showShadow = true
        #expect(Preferences.shadowStyle == .contact)
        Preferences.resetAll()
        #expect(Preferences.shadowStyle == .original)
        #expect(Preferences.showShadow)
        Preferences.storage.set("unrecognized", forKey: "shadowStyle")
        #expect(Preferences.shadowStyle == .original)
    }

    @Test func shadowStyleConfigurationIsAtomicAndReadBackMatches() throws {
        _ = NSApplication.shared
        let old = Preferences.shadowStyle
        let oldVisible = Preferences.showShadow
        defer { Preferences.shadowStyle = old; Preferences.showShadow = oldVisible }
        Preferences.showShadow = true
        let bridge = ControlBridge(overlay: OverlayController(), accessibility: { false }, openSettings: { _ in }, openHandCreator: {})
        func configure(_ settings: [String: Any]) throws -> [String: Any] {
            let data = try JSONSerialization.data(withJSONObject: ["version": 1, "operation": "configure", "settings": settings])
            return try #require(JSONSerialization.jsonObject(with: bridge.handle(data)) as? [String: Any])
        }
        let response = try configure(["shadowStyle": "contact"])
        #expect(response["ok"] as? Bool == true)
        let state = try #require(response["state"] as? [String: Any])
        #expect((state["settings"] as? [String: Any])?["shadowStyle"] as? String == "contact")
        for invalid: Any in ["soft", true, 2, NSNull()] {
            #expect(try configure(["shadowStyle": invalid, "shadow": false])["ok"] as? Bool == false)
            #expect(Preferences.shadowStyle == .contact)
            #expect(Preferences.showShadow)
        }
    }

    @Test func allLightProjectionsMeetAtContactAndStayFixedInScreenSpace() {
        let direction = CGSize(width: -0.49, height: -0.37)
        for angle: CGFloat in [-1.1, 0, 0.7, 1.4] {
            let tip = CGPoint(x: 80, y: 400)
            let projection = ShadowProjection.transform(direction: direction, rotation: angle, tipY: tip.y)
            let contact = tip.applying(projection)
            #expect(abs(contact.x - tip.x) < 0.0001)
            #expect(abs(contact.y - tip.y) < 0.0001)
            let point = CGPoint(x: 100, y: 300)
            let shadow = point.applying(projection)
            let dx = shadow.x - point.x, dy = shadow.y - point.y
            #expect(abs(dx * cos(angle) - dy * sin(angle) - 100 * direction.width) < 0.0001)
            #expect(abs(dx * sin(angle) + dy * cos(angle) - 100 * direction.height) < 0.0001)
        }
        let a = ShadowProjection.transform(direction: CGSize(width: -0.3, height: -0.2), rotation: 0, tipY: 400)
        let b = ShadowProjection.transform(direction: CGSize(width: -0.6, height: -0.5), rotation: 0, tipY: 400)
        func spread(_ y: CGFloat) -> CGFloat {
            let x = CGPoint(x: 80, y: y).applying(a), z = CGPoint(x: 80, y: y).applying(b)
            return hypot(x.x - z.x, x.y - z.y)
        }
        #expect(spread(400) < 0.0001)
        #expect(spread(200) > spread(350) * 3.9)
    }

    @Test func realGPUOutputIsBoundedAndDisablingCannotReviveAnInFlightShadow() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else { return }
        let asset = try #require(HandAsset.load("hand_lavender"))
        let pose = ContactShadowPose(asset: asset, width: 160, height: 100,
                                     rodLength: 900, rotation: 0.6, press: 1)
        let result = try #require(await ContactShadowRenderer.shared.render(pose))
        #expect(result.image.width <= 1024 && result.image.height <= 1024)
        #expect(result.extent.contains(pose.tip))
        let bytes = try #require(result.image.dataProvider?.data)
        let rgba = try #require(CFDataGetBytePtr(bytes))
        #expect((0..<(result.image.width * result.image.height)).contains { rgba[$0 * 4 + 3] > 80 })
        let layer = ContactShadowLayer()
        layer.update(pose)
        layer.disable()
        for _ in 0..<200 {
            if layer.diagnostics["pending"] as? Bool == false { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(layer.diagnostics["pending"] as? Bool == false)
        #expect(!layer.isReady)
        #expect(layer.layer.isHidden)
        #expect(layer.layer.contents == nil)
    }

    @Test func everyHandRendersLighterAtRestIncludingCustomHands() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else { return }
        let glove = try #require(HandAsset.load("hand_glove"))
        let custom = try CustomHands.add(glove.image, ink: 0, name: "Shadow fixture")
        // Keep the measured image, but remove its catalog entry before yielding
        // to the GPU so other suites never see this temporary pointer.
        let customAsset = try {
            defer { CustomHands.remove(custom) }
            return try #require(custom.assetName.flatMap(HandAsset.load))
        }()
        for style in PointerStyle.builtInHands + [custom] {
            let asset = try style == custom ? customAsset : #require(style.assetName.flatMap(HandAsset.load))
            let height: CGFloat = 100
            let width = height * asset.aspect / (asset.wrist - asset.handTop)
            var peaks: [Int] = []
            for press: CGFloat in [0, 0.5, 1] {
                let pose = ContactShadowPose(asset: asset, width: width, height: height,
                                             rodLength: 900, rotation: 0.6, press: press)
                let result = try #require(await ContactShadowRenderer.shared.render(pose))
                #expect(result.image.width <= 1024 && result.image.height <= 1024, "\(style.title)")
                #expect(result.extent.contains(pose.tip), "\(style.title)")
                let bytes = try #require(result.image.dataProvider?.data)
                let rgba = try #require(CFDataGetBytePtr(bytes))
                peaks.append((0..<(result.image.width * result.image.height)).map { Int(rgba[$0 * 4 + 3]) }.max() ?? 0)
            }
            #expect(peaks[0] > 0, "\(style.title)")
            #expect(Double(peaks[0]) < Double(peaks[2]) * 0.7, "\(style.title)")
            #expect(peaks[0] < peaks[1] && peaks[1] < peaks[2], "\(style.title)")
        }
    }

    @Test func quickTapTransitionsIntoContactThenReturnsToRest() {
        var response = ContactShadowResponse()
        response.update(at: 10, held: false)
        #expect(response.amount == 0)
        response.press(at: 10)
        #expect(response.amount == 0)
        response.update(at: 10.016, held: false)
        let entering = response.amount
        #expect(entering > 0 && entering < 0.8)
        response.update(at: 10.070, held: false)
        #expect(response.amount > 0.9)
        response.update(at: 10.120, held: false)
        #expect(response.amount > 0 && response.amount < entering)
        response.update(at: 10.6, held: false)
        #expect(response.amount == 0)
    }

    @Test func contactTransitionUsesElapsedTimeAndStaysDownWhileHeld() {
        var fast = ContactShadowResponse()
        var slow = ContactShadowResponse()
        fast.press(at: 10); slow.press(at: 10)
        for frame in 1...12 { fast.update(at: 10 + Double(frame) / 120, held: true) }
        for frame in 1...3 { slow.update(at: 10 + Double(frame) / 30, held: true) }
        #expect(abs(fast.amount - slow.amount) < 0.0001)
        fast.update(at: 12, held: true)
        #expect(fast.amount == 1)
        fast.update(at: 12.05, held: false)
        #expect(fast.amount > 0 && fast.amount < 1)
        fast.press(at: 12.05)
        let released = fast.amount
        fast.update(at: 12.075, held: true)
        #expect(fast.amount > released)
    }
}
