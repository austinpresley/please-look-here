import AppKit
import Combine
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct DrawingPracticeTests {
    private func configuration(_ fade: InkFadeStyle = .permanent) -> DrawingPracticeConfiguration {
        DrawingPracticeConfiguration(tool: .pen, color: AnnotationColor(Ink.red), width: 8,
                                     opacity: 0.6, smoothing: .medium, fadeStyle: fade,
                                     fadeDelay: 1, trailDelay: 0.2, trailSpeed: 600)
    }
    private let bounds = CGRect(x: 0, y: 0, width: 480, height: 148)

    @Test func localEditsPublishHistoryAndVisibilityForControls() {
        let session = DrawingPracticeSession(configuration: configuration())
        var changes = 0
        let subscription = session.objectWillChange.sink { changes += 1 }
        session.begin(at: .zero)
        session.extend(to: CGPoint(x: 100, y: 60))
        session.end()
        #expect(changes > 0 && session.ink.canUndo && session.ink.count == 1)
        let beforeUndo = changes
        session.undo()
        #expect(changes > beforeUndo && session.ink.count == 0)
        withExtendedLifetime(subscription) {}
    }

    @Test func practiceEditsAndConfigurationLeaveLiveHistoryAndPreferencesAlone() throws {
        let suite = try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"])
        let saved = NSDictionary(dictionary: Preferences.storage.persistentDomain(forName: suite) ?? [:])
        let live = Ink(lifetimePolicy: { InkLifetimePolicy(style: .permanent, delay: 1, trailDelay: 1, trailSpeed: 100) })
        live.addText("Live label", at: .zero, width: 8)
        let history = live.document.annotations
        var now: TimeInterval = 0
        let practice = DrawingPracticeSession(configuration: configuration(), clock: { now })
        practice.replay(in: bounds)
        now = 1
        var changed = configuration(.wholeLine)
        changed.width = 16; changed.opacity = 0.2; changed.color = AnnotationColor(Ink.purple)
        #expect(practice.configure(changed))
        practice.replay(in: bounds)
        now = 2
        #expect(practice.ink.document.annotations.first?.style.width == 16)
        #expect(practice.ink.document.annotations.first?.style.opacity == 0.2)
        #expect(practice.ink.document.annotations.first?.style.color == changed.color)
        practice.begin(at: .zero); practice.extend(to: CGPoint(x: 80, y: 80)); practice.end()
        practice.undo(); practice.clear()
        #expect(live.document.annotations == history)
        #expect(live.canUndo && !live.canRedo && live.count == 1)
        let preferencesUnchanged = saved.isEqual(to: Preferences.storage.persistentDomain(forName: suite) ?? [:])
        #expect(preferencesUnchanged)
    }

    @Test(arguments: [InkFadeStyle.wholeLine, .trail])
    func timedSampleExpiresWithFullSemanticGeometryAndRestarts(_ fade: InkFadeStyle) {
        var now: TimeInterval = 0
        let practice = DrawingPracticeSession(configuration: configuration(fade), clock: { now })
        practice.replay(in: bounds)
        now = 0.95
        let original = practice.ink.document.annotations
        #expect(original.count == 1)
        now = 20; practice.ink.advanceTrails()
        #expect(practice.ink.count == 0)
        #expect(practice.ink.document.annotations == original)
        #expect(practice.ink.canUndo)
        var changed = configuration(fade)
        changed.trailSpeed = 80; changed.fadeDelay = 3
        #expect(practice.configure(changed))
        practice.replay(in: bounds)
        now = 21
        #expect(practice.ink.count == 1)
        #expect(practice.ink.document.annotations.first?.id != original.first?.id)
        #expect(!practice.configure(changed))
    }

    @Test func permanentSampleStaysAndLocalInteractCannotDraw() {
        var now: TimeInterval = 0
        let practice = DrawingPracticeSession(configuration: configuration(), clock: { now })
        practice.replay(in: bounds)
        now = 1
        let sample = practice.ink.document.annotations
        now = 100; practice.ink.advanceTrails()
        #expect(practice.ink.count == 1)
        practice.mode = .interact
        practice.begin(at: .zero); practice.extend(to: CGPoint(x: 80, y: 80)); practice.end()
        #expect(practice.ink.document.annotations == sample)
        practice.mode = .draw
        practice.begin(at: .zero); practice.extend(to: CGPoint(x: 80, y: 80))
        practice.mode = .interact; practice.end()
        #expect(practice.ink.document.annotations == sample)
        practice.clear()
        #expect(practice.ink.count == 0 && !practice.ink.canUndo)
    }

    @Test func practiceUsesTextHighlighterAndEraserLocally() {
        var config = configuration()
        config.tool = .text
        let practice = DrawingPracticeSession(configuration: config)
        practice.text = "Local label"; practice.begin(at: CGPoint(x: 100, y: 60)); practice.end()
        #expect(practice.ink.document.annotations.count == 1)
        config.tool = .eraser; practice.configure(config)
        practice.begin(at: CGPoint(x: 104, y: 64)); practice.end()
        #expect(practice.ink.count == 0)
        practice.undo(); #expect(practice.ink.count == 1)
        config.tool = .highlighter; practice.configure(config)
        practice.begin(at: .zero); practice.extend(to: CGPoint(x: 100, y: 40)); practice.end()
        #expect(practice.ink.document.annotations.last?.style.isHighlighter == true)
        #expect(practice.ink.document.annotations.last?.style.width == 24)
    }
}
