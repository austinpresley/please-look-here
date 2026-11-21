import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct GestureArtworkTests {
    private func samePixels(_ a: CGImage, _ b: CGImage) -> Bool {
        a.width == b.width && a.height == b.height &&
        a.dataProvider?.data as Data? == b.dataProvider?.data as Data?
    }
    @Test func allSeventyTwoBundledCanvasesLoadDirectlyAndKeepBaseAnchors() throws {
        #expect(PointerStyle.builtInHands.count == 36)
        var resources = Set<String>()
        for style in PointerStyle.builtInHands {
            let base = try #require(style.assetName.flatMap(HandAsset.load))
            for slot in HandGestureSlot.allCases {
                let name = try #require(HandGestureCatalog.bundledName(slot, style: style))
                resources.insert(name)
                #expect(name == "gesture_\(style.rawValue)_\(slot == .first ? "ok" : "shaka")")
                #expect(HandAsset.bundledImageURL(name) != nil)
                let source = try #require(HandAsset.loadBundledImage(name))
                let image = try #require(HandGestureCatalog.image(slot, style: style))
                #expect(source.width == 1024 && source.height == 1536)
                #expect(samePixels(source, image))
                let pose = base.replacingImage(image)
                #expect(pose.wrist == base.wrist && pose.tip == base.tip && pose.rodX == base.rodX && pose.handTop == base.handTop)
                #expect(HandGestureCatalog.signature(for: style).contains(name))
            }
        }
        #expect(resources.count == 72)
    }
    @Test func customCanvasWinsThenRestoreRevealsBundledPoseAndInvalidatesCache() throws {
        let style = PointerStyle.lavender, slot = HandGestureSlot.first
        let url = HandGestureCatalog.url(for: slot, style: style)
        let previous = try? Data(contentsOf: url)
        defer {
            if let previous { try? previous.write(to: url) }
            else { try? HandGestureCatalog.restore(slot, style: style) }
            HandGestureCatalog.forget()
        }
        try HandGestureCatalog.restore(slot, style: style)
        let base = try #require(HandAsset.load("hand_lavender"))
        let originalSignature = HandGestureCatalog.signature(for: style)
        let bundled = try #require(HandGestureCatalog.image(slot, style: style))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try HandMaker.write(base.image, to: url)
        #expect(HandGestureCatalog.signature(for: style) != originalSignature)
        var loadedBundle = false
        let custom = try #require(HandGestureCatalog.resolve(slot, style: style, reference: base, bundledImage: { _ in loadedBundle = true; return nil }))
        #expect(!loadedBundle && samePixels(custom, base.image))
        #expect(!samePixels(try #require(HandGestureCatalog.image(slot, style: style)), bundled))
        try HandGestureCatalog.restore(slot, style: style)
        #expect(HandGestureCatalog.signature(for: style) == originalSignature)
        #expect(samePixels(try #require(HandGestureCatalog.image(slot, style: style)), bundled))
    }
    @Test func missingBundledArtworkFallsBackToGenericComposition() throws {
        let base = try #require(HandAsset.load("hand_robot"))
        let actual = try #require(HandGestureCatalog.resolve(.second, style: .robot, reference: base, bundledImage: { _ in nil }))
        let generic = try #require(HandAsset.load(HandGestureSlot.second.assetName))
        let expected = try #require(HandMaker.composeGesture(generic, reference: base))
        #expect(samePixels(actual, expected))
    }
    @Test func customHandsUseGenericThenCustomAndNonHandsHaveNoGestures() throws {
        let base = try #require(HandAsset.load("hand_lavender"))
        let custom = try CustomHands.add(base.image, ink: 0x8040bf, name: "Gesture fallback fixture")
        defer { _ = try? CustomHands.remove(custom); CustomHands.reload(); HandGestureCatalog.forget() }
        for slot in HandGestureSlot.allCases {
            #expect(HandGestureCatalog.bundledName(slot, style: custom) == nil)
            let image = try #require(HandGestureCatalog.image(slot, style: custom))
            let expected = try #require(HandAsset.load(slot.assetName).flatMap { HandMaker.composeGesture($0, reference: base) })
            #expect(samePixels(image, expected))
        }
        let customURL = HandGestureCatalog.url(for: .first, style: custom)
        try FileManager.default.createDirectory(at: customURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try HandMaker.write(base.image, to: customURL)
        #expect(samePixels(try #require(HandGestureCatalog.image(.first, style: custom)), base.image))
        for style in PointerStyle.presentationStyles {
            #expect(HandGestureCatalog.image(.first, style: style) == nil)
            #expect(HandGestureCatalog.bundledName(.second, style: style) == nil)
        }
    }
}
