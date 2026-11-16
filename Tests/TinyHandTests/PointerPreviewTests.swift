import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct PointerPreviewTests {
    @Test func rendererHasVisibleBoundsImmediatelyAfterHostResize() {
        let view = PointerPreviewView(configuration: .current)
        view.setFrameSize(NSSize(width: 504, height: 180))
        #expect(view.arm.frame == view.bounds)
        view.setFrameSize(NSSize(width: 320, height: 160))
        #expect(view.arm.frame == view.bounds)
        view.stop()
    }
    private func configuration(size: CGFloat = 0.13) -> PointerPreviewConfiguration {
        PointerPreviewConfiguration(style: .laser, size: size, shadow: false, shadowStyle: .original, motion: .original, tapSwing: 0)
    }
    @Test func settingsAdapterUsesEffectivePointerValuesWithoutWritingThem() throws {
        let suite = try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"])
        let original = Preferences.storage.persistentDomain(forName: suite) ?? [:]
        defer { Preferences.storage.setPersistentDomain(original, forName: suite) }
        PointerStyle.saved = .lavender
        Preferences.pointerSize = 0.06; Preferences.showShadow = false
        try Preferences.updatePointer("lavender") { $0.size = 0.18; $0.shadow = true; $0.shadowStyle = .contact }
        let before = NSDictionary(dictionary: Preferences.storage.persistentDomain(forName: suite) ?? [:])
        let preview = PointerPreviewConfiguration.current
        #expect(preview.style == .lavender && preview.size == 0.18 && preview.shadow && preview.shadowStyle == .contact)
        let preferencesUnchanged = before.isEqual(to: Preferences.storage.persistentDomain(forName: suite) ?? [:])
        #expect(preferencesUnchanged)
    }
    @Test func localPlaybackIsBoundedFinishesAndCanBeCanceled() {
        let bounds = CGRect(x: 0, y: 0, width: 480, height: 180)
        var playback = PointerPreviewPlayback()
        playback.previewMotion(at: 10); playback.previewTap(at: 10)
        playback.advance(at: 10.2, bounds: bounds, reduceMotion: false)
        #expect(playback.held && playback.playing && bounds.contains(playback.cursor))
        playback.advance(at: 10.4, bounds: bounds, reduceMotion: false)
        #expect(!playback.held && playback.playing)
        playback.advance(at: 12.1, bounds: bounds, reduceMotion: false)
        #expect(!playback.playing && bounds.contains(playback.cursor))
        playback.previewMotion(at: 13); playback.previewTap(at: 13); playback.cancel()
        #expect(!playback.held && !playback.playing)
        playback.previewMotion(at: 14); playback.move(to: CGPoint(x: 80, y: 90))
        playback.advance(at: 15, bounds: bounds, reduceMotion: false)
        #expect(playback.cursor == CGPoint(x: 80, y: 90) && !playback.playing)
    }
    @Test func hostClaimsOnlyItsOwnLocalBounds() {
        let parent = NSView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
        let preview = PointerPreviewView(configuration: configuration())
        preview.frame = CGRect(x: 40, y: 80, width: 480, height: 180)
        parent.addSubview(preview)
        #expect(preview.hitTest(CGPoint(x: 60, y: 100)) === preview)
        #expect(preview.hitTest(CGPoint(x: 20, y: 20)) == nil)
    }
    @Test func reduceMotionStopsDecorativeTravel() {
        var playback = PointerPreviewPlayback()
        playback.previewMotion(at: 0)
        playback.advance(at: 0.2, bounds: CGRect(x: 0, y: 0, width: 480, height: 180), reduceMotion: true)
        #expect(!playback.playing)
        #expect(playback.cursor == CGPoint(x: 240, y: 90))
    }
    @Test func localRendererNeverWritesPreferencesOrAddsLiveInk() throws {
        let suite = try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"])
        let before = NSDictionary(dictionary: Preferences.storage.persistentDomain(forName: suite) ?? [:])
        let live = Ink(lifetimePolicy: { InkLifetimePolicy(style: .permanent, delay: 1, trailDelay: 1, trailSpeed: 100) })
        live.addText("Live ink", at: .zero, width: 8)
        let history = live.document.annotations
        let view = PointerPreviewView(configuration: configuration())
        view.frame = CGRect(x: 0, y: 0, width: 480, height: 180)
        view.layoutSubtreeIfNeeded()
        var changed = configuration(size: 0.2)
        changed.motion = .responsive; changed.tapSwing = 2; changed.shadow = true; changed.shadowStyle = .contact
        view.configure(changed, tap: 1, motion: 1)
        view.stop()
        #expect(!view.playback.playing && !view.playback.held)
        #expect(view.arm.ink.document.annotations.isEmpty)
        #expect(live.document.annotations == history && live.count == 1 && !live.canRedo)
        let preferencesUnchanged = before.isEqual(to: Preferences.storage.persistentDomain(forName: suite) ?? [:])
        #expect(preferencesUnchanged)
    }
    @Test func explicitRendererSizeUpdatesItsOwnLayersWithoutLivePreferenceChanges() throws {
        let arm = ArmView(frame: CGRect(x: 0, y: 0, width: 480, height: 180), previewConfiguration: configuration())
        arm.aim(cursor: CGPoint(x: 240, y: 100))
        let dot = try #require(arm.layer?.sublayers?.compactMap { $0 as? CAShapeLayer }.first)
        let first = try #require(dot.path?.boundingBoxOfPath.width)
        arm.applyPreviewConfiguration(configuration(size: 0.2))
        arm.aim(cursor: CGPoint(x: 240, y: 100))
        let enlarged = try #require(dot.path?.boundingBoxOfPath.width)
        #expect(enlarged > first)
        NotificationCenter.default.post(name: Preferences.changed, object: nil)
        arm.aim(cursor: CGPoint(x: 240, y: 100))
        #expect(dot.path?.boundingBoxOfPath.width == enlarged)
        #expect(arm.ink.document.annotations.isEmpty)
    }
}
