import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct PresentationPointerTests {
    init() { Preferences.resetAll() }

    private func pixels(_ view: ArmView) throws -> [UInt8] {
        let context = try #require(CGContext(data: nil, width: Int(view.bounds.width), height: Int(view.bounds.height),
                                           bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        view.layer?.render(in: context)
        let image = try #require(context.makeImage())
        let data = try #require(image.dataProvider?.data)
        return Array(UnsafeBufferPointer(start: CFDataGetBytePtr(data), count: CFDataGetLength(data)))
    }

    @Test func spotlightRendersClearCenterFeatherAndUniformSurroundings() throws {
        _ = NSApplication.shared
        let view = ArmView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        view.setStyle(.spotlight)
        view.aim(cursor: CGPoint(x: 400, y: 300))
        let rgba = try pixels(view)
        func alpha(_ x: Int, _ y: Int) -> Int { Int(rgba[(y * 800 + x) * 4 + 3]) }
        #expect(view.style == .spotlight)
        #expect(alpha(410, 300) == 0)
        #expect(abs(alpha(20, 20) - 158) <= 2)
        // A diagonal outside the circle must not receive two layers of shade.
        #expect(abs(alpha(480, 380) - alpha(20, 20)) <= 2)
        let radius = SpotlightLayer.radius(height: 600, size: Preferences.pointerSize)
        let feather = alpha(400 + Int(radius * 1.08), 300)
        #expect(feather > 15 && feather < 145)
        let join = 400 - Int(radius / 0.85)
        for x in (join - 3)...(join + 3) {
            #expect(abs(alpha(x, 380) - alpha(20, 20)) <= 2)
        }
    }

    @Test func spotlightHidingSwitchingAndSizeChangesCannotLeaveStaleDimming() throws {
        _ = NSApplication.shared
        let view = ArmView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let cursor = CGPoint(x: 400, y: 300)
        view.setStyle(.spotlight)
        view.aim(cursor: cursor)
        #expect(try pixels(view)[(300 * 800 + 510) * 4 + 3] > 150)
        Preferences.pointerSize = Preferences.pointerSizeRange.upperBound
        view.aim(cursor: cursor)
        #expect(try pixels(view)[(300 * 800 + 510) * 4 + 3] == 0)
        view.pointerHidden = true
        #expect(try pixels(view).allSatisfy { $0 == 0 })
        view.pointerHidden = false
        #expect(try pixels(view)[3] > 150)
        view.setStyle(.laser)
        view.aim(cursor: cursor)
        #expect(try pixels(view)[3] == 0)
        view.setStyle(.spotlight)
        view.aim(cursor: cursor)
        #expect(try pixels(view)[3] > 150)
        // Aperture placement also works when the cursor is at a display corner.
        view.aim(cursor: CGPoint(x: 0, y: 0))
        // Bitmap rows run from the top, while the AppKit cursor uses bottom-left coordinates.
        #expect(try pixels(view)[(590 * 800 + 10) * 4 + 3] == 0)
        #expect(try pixels(view)[(10 * 800 + 790) * 4 + 3] > 150)
    }

    @Test func telescopingTipRemainsAtCursorAcrossSizesAndDisplayPositions() {
        for display in [CGSize(width: 800, height: 600), CGSize(width: 3024, height: 1964)] {
            for size in [Preferences.pointerSizeRange.lowerBound, 0.13, Preferences.pointerSizeRange.upperBound] {
                for cursor in [CGPoint.zero, CGPoint(x: display.width, y: display.height), CGPoint(x: 180, y: 420)] {
                    let grip = CGPoint(x: display.width * 0.8, y: -display.height * 0.12)
                    let pose = PresentationPointerPose(cursor: cursor, grip: grip, height: display.height, size: size)
                    #expect(abs(pose.tip.x - cursor.x) < 0.00001)
                    #expect(abs(pose.tip.y - cursor.y) < 0.00001)
                    #expect(pose.width >= 5 && pose.width <= 22)
                }
            }
        }
    }

    @Test func rodRendersItsTipAndHidesWithThePointer() throws {
        _ = NSApplication.shared
        Preferences.showShadow = false
        let view = ArmView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        view.setStyle(.presentation)
        view.aim(cursor: CGPoint(x: 400, y: 300))
        let rgba = try pixels(view)
        #expect(view.style == .presentation)
        #expect(rgba.contains { $0 > 0 })
        // The coral cap occupies the few pixels immediately behind the cursor.
        let tipArea = (296...304).flatMap { y in (396...406).map { x in (y * 800 + x) * 4 } }
        #expect(tipArea.contains { rgba[$0] > rgba[$0 + 1] && rgba[$0 + 3] > 200 })
        view.press(); view.held = true; view.aim(cursor: CGPoint(x: 400, y: 300))
        #expect(view.style == .presentation)
        view.pointerHidden = true
        #expect(try pixels(view).allSatisfy { $0 == 0 })
    }

    @Test func newPointersUseCatalogSelectionDisablingCyclingAndAutomation() throws {
        _ = NSApplication.shared
        let overlay = OverlayController()
        let bridge = ControlBridge(overlay: overlay, accessibility: { false }, openSettings: { _ in }, openHandCreator: {})
        func request(_ operation: String, _ fields: [String: Any] = [:]) throws -> [String: Any] {
            var body = fields
            body["version"] = 1; body["operation"] = operation
            return try #require(JSONSerialization.jsonObject(with: bridge.handle(JSONSerialization.data(withJSONObject: body))) as? [String: Any])
        }
        let pins = Preferences.pinnedStyles
        for style in [PointerStyle.spotlight, .presentation] {
            #expect(style.assetName == nil)
            #expect(PointerCatalog.selectableStyles.contains(style))
            #expect(try request("style", ["style": style.rawValue])["ok"] as? Bool == true)
            #expect(overlay.style == style && !overlay.isActive && overlay.mode == .point)
            let icon = try #require(Toolbar.icon(for: style)?.tiffRepresentation)
            #expect(!icon.isEmpty)
            try PointerCatalog.setEnabled(false, for: style)
            #expect(try request("style", ["style": style.rawValue, "activate": true])["ok"] as? Bool == false)
            #expect(!overlay.isActive)
            try PointerCatalog.setEnabled(true, for: style)
        }
        #expect(try PointerCatalog.nextSelectable(after: .laser) == .spotlight)
        #expect(try PointerCatalog.nextSelectable(after: .spotlight) == .presentation)
        #expect(try PointerCatalog.nextSelectable(after: .presentation) == .lavender)
        #expect(Preferences.pinnedStyles == pins)
        let styles = try #require(request("styles")["styles"] as? [[String: Any]])
        #expect(styles.contains { $0["id"] as? String == "spotlight" && $0["type"] as? String == "spotlight" })
        #expect(styles.contains { $0["id"] as? String == "presentation" && $0["type"] as? String == "presentation" })
    }

    @Test func presentationThumbnailIncludesTheAngledTipAndGrip() throws {
        let image = try #require(PresentationPointerArtwork.icon(for: .presentation)?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let context = try #require(CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 0,
                                           space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 128, height: 128))
        let result = try #require(context.makeImage())
        let data = try #require(result.dataProvider?.data)
        let rgba = try #require(CFDataGetBytePtr(data))
        let cap = (12...25).flatMap { y in (24...36).map { x in (y * 128 + x) * 4 } }
        #expect(cap.contains { rgba[$0] > rgba[$0 + 1] && rgba[$0 + 3] > 200 })
        let grip = (95...115).flatMap { y in (88...106).map { x in (y * 128 + x) * 4 } }
        #expect(grip.contains { rgba[$0 + 3] > 200 })
    }
}
