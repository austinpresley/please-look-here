import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct GettingStartedPracticeTests {
    private func makeSession() -> GettingStartedPracticeSession {
        GettingStartedPracticeSession(pointerConfiguration: PointerPreviewConfiguration(style: .laser, size: 0.4,
            shadow: false, shadowStyle: .original, motion: .original, tapSwing: 0))
    }
    @Test func lessonsReplayAndKeepPointerVisibilitySeparateFromInteract() {
        let session = makeSession()
        #expect(session.lesson == .pointer && !session.pointerOn && session.interactOn)
        #expect(session.drawing.mode == .interact)
        session.pointerOn = true
        #expect(session.interactOn)
        session.select(.interact)
        #expect(!session.interactOn)
        session.interactOn = true
        session.clickPracticeButton()
        #expect(session.clicks == 1)
        session.interactOn = false
        session.clickPracticeButton()
        #expect(session.clicks == 1 && session.pointerOn && session.drawing.mode == .draw)
        session.pointerOn = false
        #expect(session.drawing.mode == .interact)
        session.select(.drawing)
        #expect(session.pointerOn && !session.interactOn && session.drawing.mode == .draw)
        let replay = session.replay
        session.replayStep()
        #expect(session.lesson == .drawing && session.replay == replay + 1)
        session.replayAll()
        #expect(session.lesson == .pointer && !session.pointerOn && session.interactOn && session.clicks == 0)
    }

    @Test func localModeChangesAndLessonChangesCancelDrawingDrafts() {
        let session = makeSession()
        session.select(.drawing)
        session.drawing.begin(at: .zero)
        session.drawing.extend(to: CGPoint(x: 80, y: 80))
        #expect(session.drawing.ink.isDrawing)
        session.interactOn = true
        #expect(!session.drawing.ink.isDrawing)
        session.drawing.end()
        #expect(session.drawing.ink.document.annotations.isEmpty)
        session.interactOn = false
        session.drawing.begin(at: .zero)
        session.select(.radial)
        #expect(!session.drawing.ink.isDrawing && session.drawing.ink.document.annotations.isEmpty)
        session.beginRadial()
        session.select(.pointer)
        #expect(session.radial == nil)
    }

    @Test func radialUsesRealCategoryThresholdsAndCommitsOnlyLocalFeedback() {
        let session = makeSession()
        session.beginRadial()
        #expect(session.radial == nil)
        session.select(.radial)
        session.beginRadial()
        session.moveRadialToTools()
        #expect(session.radial?.group == "tools")
        session.moveRadialToPen()
        #expect(session.radial?.candidate?.id == "pen")
        session.releaseRadial()
        #expect(session.radial == nil && session.radialFeedback.contains("Pen selected in practice"))
        session.beginRadial()
        session.moveRadialToTools()
        session.moveRadial(to: CGPoint(x: 296, y: 296))
        #expect(session.radial?.group == nil)
        session.releaseRadial()
        #expect(session.radialFeedback.hasPrefix("Cancelled"))
        session.beginRadial(); session.moveRadialToTools(); session.moveRadialToPen()
        session.cancel()
        #expect(session.radial == nil && session.radialFeedback.hasPrefix("Cancelled"))
        session.beginRadial()
        session.interactOn = false
        #expect(session.radial == nil)
    }

    @Test func practiceAndShortcutNavigationDoNotWritePreferencesOrLiveInk() throws {
        let suite = try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"])
        let original = Preferences.storage.persistentDomain(forName: suite) ?? [:]
        defer { Preferences.storage.setPersistentDomain(original, forName: suite) }
        Preferences.toggleShortcut = Shortcut(keyCode: 8, modifiers: 2048, display: "⌥C")
        Preferences.setShortcut(Shortcut(keyCode: 9, modifiers: 2048, display: "⌥V"), for: .mode)
        Preferences.radialTrigger = .option
        let live = Ink(lifetimePolicy: { InkLifetimePolicy(style: .permanent, delay: 3, trailDelay: 1, trailSpeed: 100) })
        live.addText("Keep live ink", at: CGPoint(x: 24, y: 24), width: 8)
        let saved = NSDictionary(dictionary: Preferences.storage.persistentDomain(forName: suite) ?? [:])
        let shortcuts = Preferences.shortcutState
        let history = live.document.annotations
        let session = makeSession()
        for lesson in PracticeLesson.allCases { session.select(lesson); session.replayStep() }
        session.select(.drawing)
        session.drawing.begin(at: .zero); session.drawing.extend(to: CGPoint(x: 80, y: 80)); session.drawing.end()
        #expect(session.annotationCount == 1)
        session.drawing.undo()
        #expect(session.annotationCount == 0)
        session.drawing.replay(in: CGRect(x: 0, y: 0, width: 400, height: 180))
        session.select(.radial)
        session.beginRadial(); session.moveRadialToTools(); session.moveRadialToPen(); session.releaseRadial()
        session.stop()
        let settings = SettingsModel()
        var recordingRequests = 0
        var assignmentRequests = 0
        settings.onRecording = { _ in recordingRequests += 1 }
        settings.applyToggleShortcut = { _ in assignmentRequests += 1; return false }
        settings.applyPresentationShortcut = { _, _ in assignmentRequests += 1; return false }
        for target in PracticeShortcutTarget.allCases { settings.focusShortcut(target) }
        #expect(recordingRequests == 0 && assignmentRequests == 0)
        #expect(NSDictionary(dictionary: Preferences.shortcutState).isEqual(to: shortcuts))
        #expect(saved.isEqual(to: Preferences.storage.persistentDomain(forName: suite) ?? [:]))
        #expect(live.document.annotations == history && live.canUndo && !live.canRedo)
        #expect(session.drawing.ink.document.annotations.isEmpty)
    }

    @Test func shortcutTargetsMatchRealCommandsAndRepeatedLinksProduceNewRequests() {
        #expect(PracticeLesson.allCases.map(\.shortcutTarget) == [.pointer, .drawing, .interact, .radial])
        #expect(PracticeShortcutTarget.allCases.map(\.rawValue) == ["toggle", "mode", "pen", "radial"])
        #expect(PresentationAction(rawValue: PracticeShortcutTarget.interact.rawValue) == .mode)
        #expect(PresentationAction(rawValue: PracticeShortcutTarget.drawing.rawValue)?.tool == .pen)
        let settings = SettingsModel()
        for target in PracticeShortcutTarget.allCases {
            settings.focusShortcut(target)
            #expect(settings.section == .shortcuts && settings.shortcutFocusRequest?.target == target)
            let first = settings.shortcutFocusRequest
            settings.focusShortcut(target)
            #expect(settings.shortcutFocusRequest != first)
        }
    }

    @Test func readinessExplainsDesktopRestrictionsWithoutBlockingLocalPractice() {
        let unavailable = PracticeReadiness(drawingAllowed: false, radialAssigned: false, capturing: false)
        #expect(unavailable.message(for: .drawing).contains("Local practice is ready without permission"))
        #expect(unavailable.message(for: .radial).contains("choose a Hold to open modifier"))
        #expect(unavailable.message(for: .radial).contains("allow Accessibility"))
        let capturing = PracticeReadiness(drawingAllowed: true, radialAssigned: true, capturing: true)
        #expect(capturing.message(for: .drawing).contains("screenshot finishes"))
        #expect(capturing.message(for: .radial).contains("wait for the screenshot"))
        let ready = PracticeReadiness(drawingAllowed: true, radialAssigned: true, capturing: false)
        #expect(!ready.message(for: .radial).contains("choose a Hold"))
        #expect(ready.message(for: .radial).contains("Close this window"))
        let session = makeSession()
        session.select(.drawing)
        #expect(session.drawing.mode == .draw)
        session.select(.radial); session.beginRadial()
        #expect(session.radial != nil)
        session.stop()
    }
}
