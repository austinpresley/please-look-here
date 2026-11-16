import AppKit
import Testing
@testable import TinyHand
@testable import LookHerePleaseDeck

@Suite(.serialized) @MainActor struct AnnotationEditingTests {
    private func permanentInk() -> Ink {
        Ink(clock: { 0 }, lifetimePolicy: { InkLifetimePolicy(style: .permanent, delay: 1, trailDelay: 1, trailSpeed: 100) })
    }
    private func draw(_ tool: DrawingTool, into ink: Ink, from: CGPoint = .zero, to: CGPoint = CGPoint(x: 100, y: 100)) {
        ink.tool = tool
        ink.begin(at: from, width: 6)
        if tool != .number { ink.extend(to: to) }
        ink.end()
    }

    @Test(arguments: [DrawingTool.pen, .rectangle, .arrow, .number, .highlighter, .text])
    func eraserRemovesOneWholeObjectAndUndoRestoresIt(_ tool: DrawingTool) {
        let ink = permanentInk()
        ink.addText("Unaffected", at: CGPoint(x: 300, y: 300), width: 6)
        if tool == .text { ink.addText("Label", at: CGPoint(x: 30, y: 30), width: 6) }
        else { draw(tool, into: ink) }
        let before = ink.document.annotations
        let point: CGPoint
        switch tool {
        case .rectangle: point = CGPoint(x: 0, y: 50)
        case .number: point = .zero
        case .text: point = CGPoint(x: 40, y: 20)
        default: point = CGPoint(x: 50, y: 50)
        }
        ink.tool = .eraser
        ink.begin(at: point, width: 6)
        #expect(ink.isDrawing)
        #expect(ink.document.annotations == before)
        ink.extend(to: CGPoint(x: 310, y: 290)) // Dragging cannot erase a second object.
        ink.end()
        #expect(ink.document.annotations == Array(before.prefix(1)))
        ink.undo(); #expect(ink.document.annotations == before)
        ink.redo(); #expect(ink.document.annotations == Array(before.prefix(1)))
        ink.undo(); ink.undo()
        #expect(ink.document.annotations == Array(before.prefix(1))) // Exactly one removal checkpoint.
    }

    @Test func eraserChoosesTopmostAndCanceledOrEmptyGesturesDoNotConsumeHistory() {
        let ink = permanentInk()
        draw(.pen, into: ink); draw(.highlighter, into: ink)
        let before = ink.document.annotations
        ink.tool = .eraser
        ink.begin(at: CGPoint(x: 50, y: 50), width: 6); ink.cancel(); ink.end()
        #expect(ink.document.annotations == before)
        ink.begin(at: CGPoint(x: 400, y: 400), width: 6); ink.end()
        #expect(ink.document.annotations == before)
        ink.begin(at: CGPoint(x: 50, y: 50), width: 6); ink.end()
        #expect(ink.document.annotations == Array(before.prefix(1)))
        ink.undo(); #expect(ink.document.annotations == before)
        ink.undo(); #expect(ink.document.annotations == Array(before.prefix(1)))
    }

    @Test func eraserUsesShapeOutlineAndIgnoresExpiredObjectsAndErasedTrailPortions() {
        var time: TimeInterval = 0
        let ink = Ink(clock: { time }, lifetimePolicy: { InkLifetimePolicy(style: .trail, delay: 1, trailDelay: 1, trailSpeed: 100) })
        draw(.pen, into: ink, to: CGPoint(x: 200, y: 0))
        time = 2; ink.advanceTrails()
        let original = ink.document.annotations
        ink.tool = .eraser
        ink.begin(at: CGPoint(x: 30, y: 0), width: 6); ink.end()
        #expect(ink.document.annotations == original)
        ink.begin(at: CGPoint(x: 170, y: 0), width: 6); ink.end()
        #expect(ink.document.annotations.isEmpty)
        ink.undo(); #expect(ink.document.annotations == original)
        time = 20; ink.advanceTrails()
        ink.begin(at: CGPoint(x: 170, y: 0), width: 6); ink.end()
        #expect(ink.document.annotations == original)
        ink.undo(); #expect(ink.document.annotations.isEmpty)

        let permanent = permanentInk()
        draw(.rectangle, into: permanent)
        let rectangle = permanent.document.annotations
        permanent.tool = .eraser
        permanent.begin(at: CGPoint(x: 50, y: 50), width: 6); permanent.end()
        #expect(permanent.document.annotations == rectangle)
        permanent.begin(at: CGPoint(x: 2, y: 50), width: 6); permanent.end()
        #expect(permanent.document.annotations.isEmpty)
    }

    @Test func highlighterCapturesControlsAndUsesNormalHistoryAndTrailLifetime() throws {
        var time: TimeInterval = 0
        let ink = Ink(clock: { time }, lifetimePolicy: { InkLifetimePolicy(style: .trail, delay: 1, trailDelay: 1, trailSpeed: 100) })
        ink.color = Ink.red; ink.opacity = 0.8; ink.smoothing = .medium
        draw(.highlighter, into: ink, to: CGPoint(x: 100, y: 0))
        let annotation = try #require(ink.document.annotations.first)
        #expect(annotation.style.isHighlighter)
        #expect(annotation.style.width == 18)
        #expect(abs(annotation.style.opacity - 0.28) < 0.001)
        #expect(annotation.style.smoothing == .medium)
        #expect(annotation.style.color == AnnotationColor(Ink.red))
        let layer = try #require(ink.layer.sublayers?.first as? CAShapeLayer)
        #expect(layer.lineWidth == 18)
        #expect(abs((layer.strokeColor?.alpha ?? 0) - 0.28) < 0.001)
        time = 20; ink.advanceTrails()
        #expect(ink.count == 0 && ink.document.annotations == [annotation])
        ink.undo(); ink.redo()
        #expect(ink.count == 1 && ink.document.annotations == [annotation])
    }

    @Test func toolsShareProtocolAndDeckChoicesAndNewShortcutsStartUnassigned() throws {
        #expect(Array(DrawingTool.allCases.prefix(5)).map(\.rawValue) == ["pen", "rectangle", "arrow", "text", "number"])
        #expect(DrawingTool.highlighter.next == .pen)
        #expect(Set(ToolChoice.allCases.filter { $0 != .cycle }.map(\.rawValue)) == Set(DrawingTool.allCases.map(\.rawValue)))
        for tool: DrawingTool in [.eraser, .highlighter] {
            let action = try #require(PresentationAction(rawValue: tool.rawValue))
            #expect(action.tool == tool && action.drawOnly)
            #expect(Preferences.shortcut(for: action) == nil)
            #expect(tool.key.isEmpty)
            #expect(NSImage(systemSymbolName: tool.symbol, accessibilityDescription: nil) != nil)
            let settings = KeySettings(["tool": tool.rawValue])
            let command = try KeyModel.selectionCommand(action: .chooseTool, settings: settings).get()
            #expect(command.request["operation"] as? String == "tool")
            #expect(command.request["tool"] as? String == tool.rawValue)
        }
    }
    @Test func radialToolPagesKeepEveryChoiceAndHistoryTracksExpiration() {
        let geometry = RadialGeometry(cursor: CGPoint(x: 700, y: 500), bounds: CGRect(x: 0, y: 0, width: 1440, height: 1000))
        let tools = DrawingTool.allCases.map { tool in
            RadialItem(id: tool.rawValue, title: tool.title, symbol: tool.symbol, request: ["operation": "tool", "tool": tool.rawValue])
        }
        let history = [RadialItem(id: "undo", title: "Undo", symbol: "arrow.uturn.backward", request: ["operation": "undo"]),
                       RadialItem(id: "clear", title: "Clear Drawing", symbol: "trash", request: ["operation": "clear"])]
        var session = RadialSession(geometry: geometry,
                                    root: [RadialItem(id: "tools", title: "Tools", symbol: "pencil.tip", group: "tools"),
                                           RadialItem(id: "history", title: "History", symbol: "arrow.uturn.backward", group: "history")],
                                    groups: ["tools": tools, "history": history])
        _ = session.activate(0)
        #expect(session.pages == 2)
        #expect(session.items[5].id == "eraser")
        #expect(session.activate(5)?["tool"] as? String == "eraser")
        _ = session.activate(7)
        #expect(session.items[0].id == "highlighter")
        #expect(session.activate(0)?["tool"] as? String == "highlighter")
        session.back(); _ = session.activate(1)
        session.updateHistory(canUndo: true, canRedo: false, hasInk: false)
        #expect(session.items[0].enabled)
        #expect(!session.items[1].enabled)
        #expect(session.activate(1) == nil)
    }

}
