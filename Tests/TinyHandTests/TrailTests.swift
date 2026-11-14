import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct TrailTests {
    @Test func eraserProtectsRecentlyDrawnPointsAndAdvancesAtTheChosenSpeed() {
        var trail = InkTrail(at: .zero, time: 0)
        trail.append(CGPoint(x: 100, y: 0), time: 0.5)
        trail.append(CGPoint(x: 200, y: 0), time: 1)
        trail.advance(to: 1, delay: 1, speed: 100)
        #expect(trail.erased == 0)
        trail.advance(to: 1.5, delay: 1, speed: 100)
        #expect(trail.erased == 50)
        trail.advance(to: 1.75, delay: 1, speed: 100)
        #expect(trail.erased == 75)
        trail.finished = true
        trail.advance(to: 3, delay: 1, speed: 100)
        #expect(trail.complete && trail.fraction == 1)
    }

    @Test func trailRenderingKeepsCompleteGeometryForUndoAndRedo() throws {
        Preferences.inkFadeStyle = .trail; Preferences.trailDelay = 1; Preferences.trailSpeed = 100
        defer { Preferences.inkFadeStyle = .wholeLine }
        var time: TimeInterval = 0
        let ink = Ink(clock: { time })
        ink.begin(at: .zero, width: 6)
        time = 0.5; ink.extend(to: CGPoint(x: 100, y: 0))
        time = 1; ink.extend(to: CGPoint(x: 200, y: 0))
        time = 1.5; ink.advanceTrails()
        let live = try #require(ink.layer.sublayers?.first as? CAShapeLayer)
        #expect(live.strokeStart == 0.25)
        ink.end()
        #expect(ink.count == 1 && ink.hasActiveTrails)
        time = 10; ink.advanceTrails()
        #expect(live.strokeStart == 1 && !ink.hasActiveTrails)
        #expect(ink.document.annotations.count == 1)
        ink.undo(); #expect(ink.count == 0 && !ink.hasActiveTrails)
        ink.redo(); #expect(ink.count == 1 && ink.hasActiveTrails)
        let restored = try #require(ink.layer.sublayers?.first as? CAShapeLayer)
        #expect(restored.strokeStart == 0)
        if case .pen(let points) = ink.document.annotations[0].shape { #expect(points.count == 3) }
        else { Issue.record("Trail changed the annotation geometry") }
        ink.clear(); #expect(!ink.hasActiveTrails && ink.count == 0)
    }

    @Test func cancellingOrResettingAnActiveTrailStopsItsClock() {
        Preferences.inkFadeStyle = .trail
        defer { Preferences.inkFadeStyle = .wholeLine }
        let ink = Ink()
        ink.begin(at: .zero, width: 6); ink.extend(to: CGPoint(x: 100, y: 0))
        #expect(ink.hasActiveTrails)
        ink.cancel(); #expect(!ink.hasActiveTrails && !ink.isDrawing)
        ink.begin(at: .zero, width: 6); ink.extend(to: CGPoint(x: 100, y: 0)); ink.end()
        ink.reset(); #expect(!ink.hasActiveTrails && ink.layer.sublayers?.isEmpty != false)
    }

    @Test func oldKeepUntilClearedChoiceSurvivesAndTrailSettingsReset() {
        Preferences.storage.removeObject(forKey: "inkFadeStyle")
        Preferences.fadeSeconds = 0
        #expect(Preferences.inkFadeStyle == .permanent)
        Preferences.inkFadeStyle = .trail
        #expect(Preferences.fadeSeconds == 3)
        Preferences.trailDelay = 100; Preferences.trailSpeed = -10
        #expect(Preferences.trailDelay == 3 && Preferences.trailSpeed == 40)
        Preferences.resetAll()
        #expect(Preferences.inkFadeStyle == .wholeLine)
        #expect(Preferences.trailDelay == 1 && Preferences.trailSpeed == 240)
    }
}
