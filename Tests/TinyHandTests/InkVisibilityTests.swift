import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct InkVisibilityTests {
    private func withPolicy(_ style: InkFadeStyle, _ body: () throws -> Void) rethrows {
        let saved = Preferences.storage.dictionaryRepresentation()
        defer {
            for key in Preferences.storage.dictionaryRepresentation().keys { Preferences.storage.removeObject(forKey: key) }
            for (key, value) in saved { Preferences.storage.set(value, forKey: key) }
        }
        Preferences.inkFadeStyle = style
        Preferences.fadeSeconds = 1
        Preferences.trailDelay = 1
        Preferences.trailSpeed = 100
        try body()
    }

    @Test func wholeObjectExpirationHidesTextAndMarkersWithoutDeletingHistory() throws {
        try withPolicy(.wholeLine) {
            var time: TimeInterval = 0
            let ink = Ink(clock: { time })
            ink.addText("Label", at: CGPoint(x: 80, y: 80), width: 8)
            ink.tool = .number
            ink.begin(at: CGPoint(x: 30, y: 30), width: 6); ink.end()
            let original = ink.document.annotations
            time = 1.3; ink.advanceTrails()
            let label = try #require(ink.layer.sublayers?.first)
            #expect(abs(label.opacity - 0.5) < 0.001)
            time = 2; ink.advanceTrails()
            #expect(ink.count == 0)
            #expect(ink.document.annotations == original)
            #expect(label.opacity == 0)
            ink.begin(at: CGPoint(x: 30, y: 30), width: 6); ink.end()
            #expect(ink.document.annotations.count == 3)
            #expect(ink.count == 1)
            ink.undo()
            #expect(ink.document.annotations == original)
            #expect(ink.count == 0)
        }
    }

    @Test func trailPolicyExpiresTextAndMarkersAndRestoresDeletedObjectsFresh() throws {
        try withPolicy(.trail) {
            var time: TimeInterval = 0
            let ink = Ink(clock: { time })
            ink.addText("Trail label", at: CGPoint(x: 80, y: 80), width: 8)
            ink.tool = .number
            ink.begin(at: CGPoint(x: 30, y: 30), width: 6); ink.end()
            let original = ink.document.annotations
            time = 10; ink.advanceTrails()
            #expect(ink.count == 0)
            ink.clear(); ink.undo()
            #expect(ink.document.annotations == original)
            #expect(ink.count == 2)
            #expect(ink.layer.sublayers?.allSatisfy { $0.opacity == 1 } == true)
            time = 20; ink.advanceTrails()
            #expect(ink.count == 0)
            ink.undo(); #expect(ink.count == 0)
            ink.redo(); #expect(ink.count == 1)
            #expect(ink.document.annotations == original)
        }
    }

    @Test func undoMarkerMoveRestartsOnlyChangedObject() {
        withPolicy(.wholeLine) {
            var time: TimeInterval = 0
            let ink = Ink(clock: { time })
            ink.addText("Old", at: CGPoint(x: 80, y: 80), width: 8)
            time = 0.5
            ink.tool = .number
            ink.begin(at: CGPoint(x: 30, y: 30), width: 6); ink.end()
            ink.begin(at: CGPoint(x: 30, y: 30), width: 6)
            ink.extend(to: CGPoint(x: 60, y: 60)); ink.end()
            time = 10; ink.advanceTrails()
            #expect(ink.count == 0)
            ink.undo(); #expect(ink.count == 1)
            #expect(ink.document.marker(at: CGPoint(x: 30, y: 30)) != nil)
            ink.redo(); #expect(ink.count == 1)
        }
    }
    @Test func trailCanResumeAfterCatchingAnUnfinishedStroke() throws {
        try withPolicy(.trail) {
            var time: TimeInterval = 0
            let ink = Ink(clock: { time })
            ink.begin(at: .zero, width: 6)
            ink.extend(to: CGPoint(x: 100, y: 0))
            time = 10; ink.advanceTrails()
            let shape = try #require(ink.layer.sublayers?.first as? CAShapeLayer)
            #expect(shape.strokeStart == 1)
            ink.extend(to: CGPoint(x: 200, y: 0))
            #expect(shape !== ink.layer.sublayers?.first)
            let resumed = try #require(ink.layer.sublayers?.first as? CAShapeLayer)
            #expect(resumed.strokeStart == 0.5)
            #expect(ink.hasActiveTrails)
            ink.end()
            #expect(ink.document.annotations.count == 1)
        }
    }

    @Test func shapeFadingAndPermanentTextUseTheCapturedPolicy() {
        var time: TimeInterval = 0
        var policy = InkLifetimePolicy(style: .wholeLine, delay: 1, trailDelay: 1, trailSpeed: 100)
        let ink = Ink(clock: { time }, lifetimePolicy: { policy })
        for tool: DrawingTool in [.rectangle, .arrow] {
            ink.tool = tool
            ink.begin(at: .zero, width: 4); ink.extend(to: CGPoint(x: 100, y: 100)); ink.end()
        }
        policy.style = .permanent
        ink.addText("Kept", at: CGPoint(x: 200, y: 100), width: 4)
        time = 10; ink.advanceTrails()
        #expect(ink.count == 1)
        #expect(ink.document.annotations.count == 3)
        ink.clear(); ink.undo()
        #expect(ink.count == 3)
        time = 100; ink.advanceTrails()
        #expect(ink.count == 3)
    }

}
