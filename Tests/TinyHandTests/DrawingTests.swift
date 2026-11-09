import AppKit
import Testing
@testable import TinyHand

private func testStyle() -> AnnotationStyle {
    AnnotationStyle(color: AnnotationColor(NSColor.systemRed.cgColor), width: 6, opacity: 1, smoothing: .light)
}

@Suite struct DrawingGeometryTests {
    @Test func historyRestoresEditsAndClear() {
        var document = AnnotationDocument()
        let first = Annotation(shape: .pen([.zero, CGPoint(x: 40, y: 30)]), style: testStyle())
        let second = Annotation(shape: .rectangle(.zero, CGPoint(x: 80, y: 60)), style: testStyle())
        document.append(first); document.append(second)
        #expect(document.annotations == [first, second])
        document.undo(); #expect(document.annotations == [first])
        document.redo(); #expect(document.annotations == [first, second])
        document.clear(); #expect(document.annotations.isEmpty)
        document.undo(); #expect(document.annotations == [first, second])
        document.undo(); document.append(Annotation(shape: .arrow(.zero, CGPoint(x: 30, y: 20)), style: testStyle()))
        #expect(!document.canRedo)
    }

    @Test func emptyGesturesDoNotConsumeUndo() {
        var document = AnnotationDocument()
        for shape: Annotation.Shape in [.pen([.zero]), .rectangle(.zero, .zero), .arrow(.zero, CGPoint(x: 1, y: 1)), .text("  ", .zero)] {
            document.append(Annotation(shape: shape, style: testStyle()))
        }
        document.clear(); document.remove(UUID())
        #expect(document.annotations.isEmpty)
        #expect(!document.canUndo)
    }

    @Test func historyIsBoundedWithoutLosingRecentEdits() {
        var document = AnnotationDocument()
        for n in 1...103 { document.append(Annotation(shape: .number(n, CGPoint(x: n, y: n)), style: testStyle())) }
        for _ in 0..<100 { document.undo() }
        #expect(document.annotations.count == 3)
        #expect(!document.canUndo)
        for _ in 0..<100 { document.redo() }
        #expect(document.annotations.count == 103)
    }

    @Test(arguments: StrokeSmoothing.allCases) func smoothingPreservesEndpoints(_ strength: StrokeSmoothing) {
        let points = (0...40).map { CGPoint(x: $0 * 3, y: $0 % 2 == 0 ? 5 : -5) }
        let result = AnnotationGeometry.smooth(points, strength: strength)
        #expect(result.first == points.first)
        #expect(result.last == points.last)
        #expect(result.count == points.count)
        if strength != .off {
            #expect(abs(result[20].y - result[21].y) < abs(points[20].y - points[21].y))
        } else { #expect(result == points) }
    }

    @Test func reverseRectangleAndArrowBounds() {
        let rectangle = Annotation(shape: .rectangle(CGPoint(x: 90, y: 80), CGPoint(x: 10, y: 20)), style: testStyle())
        #expect(AnnotationGeometry.path(rectangle).boundingBoxOfPath == CGRect(x: 10, y: 20, width: 80, height: 60))
        let arrow = Annotation(shape: .arrow(.zero, CGPoint(x: 100, y: 40)), style: testStyle())
        let box = AnnotationGeometry.path(arrow).boundingBoxOfPath
        #expect(box.minX == 0)
        #expect(box.maxX == 100)
        #expect(box.maxY >= 40)
    }

    @Test func markerHitTestingAndNumberReuse() {
        var document = AnnotationDocument()
        let first = Annotation(shape: .number(1, CGPoint(x: 30, y: 30)), style: testStyle())
        let second = Annotation(shape: .number(2, CGPoint(x: 70, y: 30)), style: testStyle())
        document.append(first); document.append(second)
        #expect(document.marker(at: CGPoint(x: 33, y: 35))?.id == first.id)
        #expect(document.marker(at: CGPoint(x: 300, y: 300)) == nil)
        #expect(document.nextNumber == 3)
        document.remove(second.id)
        #expect(document.nextNumber == 2)
        document.undo()
        #expect(document.nextNumber == 3)
    }
}

@Suite(.serialized) @MainActor struct InkInteractionTests {
    @Test func markersMoveDeleteAndUndoAsWholeGestures() {
        _ = NSApplication.shared
        Preferences.fadeSeconds = 0
        let ink = Ink()
        ink.tool = .number
        ink.begin(at: CGPoint(x: 30, y: 30), width: 6); ink.end()
        #expect(ink.count == 1)
        ink.begin(at: CGPoint(x: 30, y: 30), width: 6)
        ink.extend(to: CGPoint(x: 60, y: 70)); ink.end()
        if case .number(let n, let point) = ink.document.annotations[0].shape {
            #expect(n == 1); #expect(point == CGPoint(x: 60, y: 70))
        } else { Issue.record("Expected a number marker") }
        ink.undo()
        #expect(ink.document.marker(at: CGPoint(x: 30, y: 30)) != nil)
        ink.redo()
        ink.begin(at: CGPoint(x: 60, y: 70), width: 6); ink.end()
        #expect(ink.count == 0)
        ink.undo(); #expect(ink.count == 1)
    }

    @Test func canceledDraftPreservesCompletedDrawing() {
        Preferences.fadeSeconds = 0
        let ink = Ink()
        ink.begin(at: .zero, width: 4); ink.extend(to: CGPoint(x: 40, y: 20)); ink.end()
        ink.tool = .rectangle
        ink.begin(at: .zero, width: 10); ink.extend(to: CGPoint(x: 90, y: 80)); ink.cancel()
        #expect(ink.count == 1)
        #expect(!ink.isDrawing)
        ink.addText("Label", at: CGPoint(x: 80, y: 80), width: 8)
        #expect(ink.count == 2)
        ink.undo(); #expect(ink.count == 1)
        ink.clear(); ink.undo(); #expect(ink.count == 1)
    }

    @Test func strokeStyleIsCapturedAtCreation() {
        let ink = Ink()
        ink.opacity = 0.35; ink.smoothing = .medium
        ink.begin(at: .zero, width: 12); ink.extend(to: CGPoint(x: 30, y: 30)); ink.end()
        ink.opacity = 1; ink.smoothing = .off
        let style = ink.document.annotations[0].style
        #expect(style.width == 12)
        #expect(abs(style.opacity - 0.35) < 0.001)
        #expect(style.smoothing == .medium)
    }
}

@Suite struct MotionTests {
    @Test func methodsHaveDifferentGripFollow() {
        #expect(PointerMotion.original.gripPosition(previous: 0, target: 10) == 0.8)
        #expect(abs(PointerMotion.responsive.gripPosition(previous: 0, target: 10) - 2.8) < 0.001)
        #expect(PointerMotion.responsive.gripPosition(previous: 0, target: 40) == 22)
        #expect(PointerMotion.responsive.gripPosition(previous: 0, target: 100) == 100)
    }
    @Test(arguments: PointerMotion.allCases) func motionDoesNotOvershoot(_ method: PointerMotion) {
        #expect(method.gripPosition(previous: nil, target: 300) == 300)
        for target: CGFloat in [-300, -30, 0, 30, 300] {
            var position: CGFloat = 0
            for _ in 0..<100 {
                position = method.gripPosition(previous: position, target: target)
                #expect(position >= min(0, target) && position <= max(0, target))
            }
            #expect(abs(position - target) < 0.1)
        }
    }
}
