import AppKit
import Carbon.HIToolbox
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct GestureTests {
    @Test func newestHeldPoseWinsAndOldKeyReleaseCannotClearIt() {
        var state = HandGestureSession()
        let one = Shortcut(keyCode: 18, modifiers: UInt32(controlKey), display: "Control-1")
        let two = Shortcut(keyCode: 19, modifiers: UInt32(controlKey | optionKey), display: "Control-Option-2")
        state.begin(.first, owner: "one", shortcut: one)
        state.begin(.second, owner: "two", shortcut: two)
        state.begin(.first, owner: "one", shortcut: one)
        #expect(state.active == .second)
        state.end("one"); #expect(state.active == .second)
        state.retainModifiers(.control); #expect(state.active == nil)
        state.begin(.first, owner: "one", shortcut: one)
        state.begin(.second, owner: "two", shortcut: two)
        state.releaseKey(19); #expect(state.active == .first)
        state.cancel(); #expect(state.active == nil)
    }

    @Test func bothStarterPosesKeepPointerIdentityAndPointingGeometry() throws {
        let before = PointerStyle.allCases.map(\.rawValue), pins = Preferences.pinnedStyles
        let base = try #require(HandAsset.load("hand_glove"))
        for slot in HandGestureSlot.allCases {
            let image = try #require(HandGestureCatalog.image(slot, style: .glove))
            let pose = base.replacingImage(image)
            #expect(image.width == base.image.width && image.height == base.image.height)
            #expect(pose.wrist == base.wrist && pose.tipX == base.tipX && pose.tip == base.tip && pose.rodX == base.rodX)
        }
        #expect(HandGestureCatalog.image(.first, style: .laser) == nil)
        #expect(PointerStyle.allCases.map(\.rawValue) == before && Preferences.pinnedStyles == pins)
    }

    @Test func importingAndRestoringOnlyChangesTheSelectedHandsGestureSlot() throws {
        let destination = HandGestureCatalog.url(for: .first, style: .glove)
        let original = try? Data(contentsOf: destination)
        defer {
            if let original { try? original.write(to: destination, options: .atomic) }
            else { try? HandGestureCatalog.restore(.first, style: .glove) }
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let context = try #require(CGContext(data: nil, width: 256, height: 320, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(NSColor.systemPink.cgColor)
        context.fill(CGRect(x: 72, y: 40, width: 112, height: 220))
        let input = folder.appendingPathComponent("pose.png")
        try HandMaker.write(try #require(context.makeImage()), to: input)
        let other = HandGestureCatalog.url(for: .first, style: .lavender)
        let otherBefore = try? Data(contentsOf: other)
        try HandGestureCatalog.add(from: input, slot: .first, style: .glove)
        #expect(HandGestureCatalog.hasCustom(.first, style: .glove))
        #expect(HandGestureCatalog.image(.first, style: .glove) != nil)
        let saved = try Data(contentsOf: destination)
        let bad = folder.appendingPathComponent("bad.png"); try Data("not an image".utf8).write(to: bad)
        #expect(throws: (any Error).self) { try HandGestureCatalog.add(from: bad, slot: .first, style: .glove) }
        #expect(try Data(contentsOf: destination) == saved)
        #expect((try? Data(contentsOf: other)) == otherBefore)
        Preferences.resetAll()
        #expect(HandGestureCatalog.hasCustom(.first, style: .glove))
        try HandGestureCatalog.restore(.first, style: .glove)
        #expect(!HandGestureCatalog.hasCustom(.first, style: .glove))
        #expect(HandGestureCatalog.image(.first, style: .glove) != nil)
    }

    @Test func imageGuidanceRequiresRealAlphaAndKeepsTheUsersDescription() {
        let prompt = HandMaker.prompt(for: "  coral knitted wool  ")
        #expect(prompt.contains("coral knitted wool"))
        #expect(prompt.contains("alpha channel") && prompt.contains("Do not draw a checkerboard"))
        #expect(!HandMaker.prompt(for: "  ").contains("[describe"))
    }
}
