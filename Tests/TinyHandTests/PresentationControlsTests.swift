import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct PresentationControlsTests {
    @Test func cursorIsIdempotentAndPreservesTheLastTool() {
        _ = NSApplication.shared
        Preferences.pointerMode = .point; Preferences.drawingTool = .arrow
        let overlay = OverlayController(accessibility: { false })
        defer { overlay.deactivate() }
        #expect(overlay.setMode(.point)); #expect(overlay.setMode(.point))
        #expect(overlay.controlsState.selection == .cursor && Preferences.drawingTool == .arrow)
    }
    @Test(arguments: ControlTool.drawingTools)
    func toolSelectionEntersDrawingAndModeShortcutReturnsToLastTool(_ tool: DrawingTool) {
        _ = NSApplication.shared
        Preferences.pointerMode = .point
        var enabled = false
        let tap = InputTap(installation: .init(install: { true }, isEnabled: { enabled }, setEnabled: { enabled = $0 }))
        let overlay = OverlayController(accessibility: { true }, inputTap: tap)
        defer { overlay.deactivate(); Preferences.pointerMode = .point }
        // Mode behavior is independent of native tap availability.
        #expect(overlay.chooseTool(tool))
        #expect(overlay.controlsState.selection == .drawing(tool))
        overlay.toggleMode(); #expect(overlay.controlsState.selection == .cursor)
        overlay.toggleMode(); #expect(overlay.controlsState.selection == .drawing(tool))
    }
    @Test func missingPermissionRetainsUIChoiceWhileProtocolStillRejects() throws {
        _ = NSApplication.shared
        Preferences.pointerMode = .point
        let overlay = OverlayController(accessibility: { false })
        defer { overlay.deactivate() }
        overlay.chooseToolFromControls(.highlighter)
        #expect(overlay.controlsState.selection == .drawing(.highlighter))
        #expect(overlay.controlsState.notReady && overlay.controlsState.showsColors)
        #expect(overlay.mode == .point && !overlay.isActive)
        let bridge = ControlBridge(overlay: overlay, accessibility: { false }, openSettings: { _ in }, openHandCreator: {})
        let reply = try #require(JSONSerialization.jsonObject(with: bridge.handle(JSONSerialization.data(withJSONObject: ["version": 1, "operation": "tool", "tool": "pen"]))) as? [String: Any])
        #expect(reply["ok"] as? Bool == false && Preferences.drawingTool == .highlighter)
        #expect(overlay.setMode(.point)); #expect(overlay.controlsState.selection == .cursor)
    }
    @Test(arguments: [false, true]) func hiddenPointerDoesNotChangeToolOrReadiness(_ allowed: Bool) {
        for mode in [PointerMode.point, .draw] {
            let shown = PresentationControlsState(mode: mode, tool: .pen, pointerVisible: true, drawingAllowed: allowed)
            var hidden = shown; hidden.pointerVisible = false
            #expect(shown.selection == hidden.selection && shown.showsColors == hidden.showsColors && shown.notReady == hidden.notReady)
        }
    }
    @Test func wheelCursorAlwaysEnablesAndDrawingRootHasACheck() {
        for interacting in [false, true] {
            let state = RadialCurrentState(pointerID: "glove", ink: .match, tool: .arrow, interact: interacting, tapSound: true, muted: false, toolbar: true)
            let model = RadialCatalog.make(geometry: RadialGeometry(cursor: CGPoint(x: 500, y: 500), bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000)), state: state, favorites: RadialFavorites.defaults, pointers: [], canUndo: false, canRedo: false, hasInk: false)
            #expect(model.root[4].title == "Cursor" && model.root[4].selected == interacting)
            #expect(model.root[4].request?["enabled"] as? Bool == true)
            #expect(model.root[2].showsCheck == !interacting)
        }
    }
    @Test func toolbarSharedControlsKeepTheirRealFramesAcrossAllStates() throws {
        _ = NSApplication.shared
        let toolbar = Toolbar()
        defer { toolbar.hide() }
        let initial = toolbar.verify(["selection": "cursor", "permission": true])
        let frames = try #require(initial["buttons"] as? [String: [CGFloat]])
        for selection in ControlTool.drawingTools.map(\.rawValue) + ["cursor"] {
            for permission in [false, true] {
                let next = toolbar.verify(["selection": selection, "permission": permission])
                #expect(next["buttons"] as? [String: [CGFloat]] == frames)
                #expect(next["size"] as? [CGFloat] == initial["size"] as? [CGFloat])
                #expect(next["contextWidth"] as? CGFloat == FloatingToolbarLayout.context)
            }
        }
    }
    @Test func soundStatesHaveDistinctIconsAndSymbolsExist() {
        #expect(Set([TapSoundState.on.symbol, TapSoundState.pointerMuted.symbol, TapSoundState.appMuted.symbol]).count == 3)
        for symbol in ControlTool.all.map(\.symbol) + ["speaker", "speaker.slash", "speaker.wave.2", "paintpalette", "cursorarrow.click", "scope"] {
            #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil)
        }
        #expect(ControlArtwork.hiddenHand() != nil)
    }
    @Test func mountingAndResizingPracticeCanvasDoesNotInsertSampleOrCompleteTheLesson() {
        _ = NSApplication.shared
        let session = GettingStartedPracticeSession(pointerConfiguration: .current)
        session.select(.drawing)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 180), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = GettingStartedInkView(session: session.drawing)
        for size in [CGSize(width: 400, height: 180), CGSize(width: 520, height: 240)] {
            window.setContentSize(size); window.contentView?.layoutSubtreeIfNeeded()
            #expect(session.drawing.ink.document.annotations.isEmpty && !session.succeeded)
        }
        session.replayStep(); window.contentView?.layoutSubtreeIfNeeded()
        #expect(!session.succeeded && session.annotationCount == 0)
        window.contentView = nil; window.orderOut(nil)
    }
    @Test func practiceNeverReportsSuccessBeforeTheLocalAction() {
        let session = GettingStartedPracticeSession(pointerConfiguration: .current)
        for lesson in PracticeLesson.allCases { session.select(lesson); #expect(!session.succeeded) }
        session.select(.pointer); session.clickPracticeButton(); #expect(!session.succeeded)
        session.pointerOn = true; session.clickPracticeButton(); #expect(session.succeeded)
        session.select(.drawing); session.drawing.begin(at: .zero); session.drawing.extend(to: CGPoint(x: 80, y: 80)); session.drawing.end()
        #expect(session.succeeded)
        session.select(.interact); session.clickPracticeButton(); #expect(!session.succeeded)
        session.interactOn = true; session.clickPracticeButton(); #expect(session.succeeded)
        session.select(.radial); session.beginRadial(); session.cancelRadial(); #expect(!session.succeeded)
        session.beginRadial(); session.moveRadialToTools(); session.moveRadialToPen(); session.releaseRadial(); #expect(session.succeeded)
    }
}
