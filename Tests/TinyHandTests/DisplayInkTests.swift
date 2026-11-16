import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct DisplayInkTests {
    let left = DisplayInkStore.Display(id: 11, frame: CGRect(x: -1200, y: 300, width: 1200, height: 900), scale: 1)
    let right = DisplayInkStore.Display(id: 22, frame: CGRect(x: 0, y: 0, width: 1728, height: 1117), scale: 2)

    @Test func crossingRetainsExactLocalGeometryAndIndependentUndo() {
        let store = DisplayInkStore()
        store.select(left)
        let first = store.ink
        first.begin(at: CGPoint(x: 23, y: 40), width: 4)
        first.extend(to: CGPoint(x: 300, y: 700)); first.end()
        let geometry = first.document.annotations
        store.select(right)
        let second = store.ink
        #expect(second !== first)
        second.addText("Right", at: CGPoint(x: 900, y: 600), width: 8)
        store.select(left)
        #expect(store.ink === first)
        #expect(store.ink.document.annotations == geometry)
        first.undo(); #expect(first.document.annotations.isEmpty)
        store.select(right)
        #expect(store.ink === second)
        #expect(second.document.annotations.count == 1)
        second.undo(); second.redo()
        store.select(left)
        first.redo(); #expect(first.document.annotations == geometry)
        #expect(first.scale == 1)
        #expect(second.scale == 2)
    }

    @Test func offHidesRetainedInkUntilExplicitActivation() {
        let store = DisplayInkStore()
        store.select(left); store.activate()
        store.ink.addText("Retain", at: CGPoint(x: 40, y: 40), width: 4)
        store.deactivate()
        #expect(store.layer.isHidden)
        store.select(right); store.select(left)
        #expect(store.layer.isHidden)
        #expect(store.ink.document.annotations.count == 1)
        #expect(store.ink.canUndo)
        store.activate()
        #expect(!store.layer.isHidden)
        store.ink.undo(); #expect(store.ink.document.annotations.isEmpty)
    }

    @Test func geometryChangesDoNotMoveOrResetAnnotations() {
        let store = DisplayInkStore()
        store.select(left)
        store.ink.addText("Same display", at: CGPoint(x: 700, y: 500), width: 4)
        let original = store.ink.document.annotations
        let resized = DisplayInkStore.Display(id: left.id, frame: CGRect(x: 0, y: -900, width: 1000, height: 800), scale: 2)
        store.select(resized)
        #expect(store.ink.document.annotations == original)
        #expect(store.ink.scale == 2)
        #expect(store.ink.layer.sublayers?.first?.contentsScale == 2)
        store.ink.clear(); store.ink.undo()
        #expect(store.ink.document.annotations == original)
    }
}
