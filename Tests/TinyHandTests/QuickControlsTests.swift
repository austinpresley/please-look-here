import AppKit
import Testing
@testable import TinyHand

@Suite("Quick controls browser navigation")
struct PointerBrowserModelTests {
    let entries = (PointerStyle.builtInHands + PointerStyle.presentationStyles).map { PointerCatalog.Entry(style: $0, enabled: true, available: true) }
    @Test(arguments: [(CGFloat(64), 1), (CGFloat(135), 1), (CGFloat(136), 2), (CGFloat(280), 4), (CGFloat(496), 7), (CGFloat(900), 7)])
    func adaptiveColumns(_ pair: (CGFloat, Int)) { #expect(PointerBrowserModel.columns(availableWidth: pair.0) == pair.1) }
    @Test func modifiedChordsAreIgnored() {
        #expect(PointerBrowserModel.handles([])); #expect(PointerBrowserModel.handles(.shift))
        #expect(!PointerBrowserModel.handles(.control)); #expect(!PointerBrowserModel.handles(.option)); #expect(!PointerBrowserModel.handles(.command))
        #expect(!PointerBrowserModel.handles([.control, .option]))
    }
    @Test func quickScopeUsesSavedWheelOrder() {
        var model = PointerBrowserModel(); model.scope = .quickControls
        let favorites = ["laser", "robot", "plush", "coral", "lavender", "glove"]
        #expect(model.results(entries: entries, favorites: favorites).map(\.style.rawValue) == favorites)
    }
    @Test func filterAndEligibility() {
        var model = PointerBrowserModel(); model.query = "PRESENTATION"
        #expect(model.results(entries: entries, favorites: []).map(\.style.rawValue) == ["presentation"])
        #expect(model.results(entries: [PointerCatalog.Entry(style: .glove, enabled: false, available: true), PointerCatalog.Entry(style: .laser, enabled: true, available: false)], favorites: []).isEmpty)
    }
    @Test func searchDownAndSpatialArrowsUseActualColumns() {
        var model = PointerBrowserModel(); let ids = (0..<10).map(String.init)
        model.move(.down, ids: ids, columns: 4); #expect(model.focus == .grid && model.inspected == "0")
        model.move(.right, ids: ids, columns: 4); model.move(.down, ids: ids, columns: 4); #expect(model.inspected == "5")
        model.move(.down, ids: ids, columns: 4); #expect(model.inspected == "9")
        model.move(.right, ids: ids, columns: 4); #expect(model.inspected == "9")
        model.move(.up, ids: ids, columns: 4); #expect(model.inspected == "5")
        model.move(.up, ids: ids, columns: 4); model.move(.up, ids: ids, columns: 4); #expect(model.focus == .search)
        model.focus = .grid; model.inspected = "3"; model.move(.right, ids: ids, columns: 4); #expect(model.inspected == "3")
        model.inspected = "4"; model.move(.left, ids: ids, columns: 4); #expect(model.inspected == "4")
    }
    @Test func emptyResultsRemoveProvisionalSelectionAndReturnDoesNothing() {
        var model = PointerBrowserModel(); model.inspected = "glove"; model.reconcile([])
        #expect(model.inspected == nil); #expect(model.activate("glove", valid: []) == nil)
    }
    @Test func normalActivationChoosesWhileEditingOnlySetsCandidate() {
        var model = PointerBrowserModel()
        #expect(model.activate("glove", valid: ["glove"]) == "glove")
        model.startEditing()
        #expect(model.activate("presentation", valid: ["presentation"]) == nil)
        #expect(model.candidate == "presentation" && model.editing && model.focus == .grid)
    }
    @Test func assignmentRestoresSlotFocusAndFinishClearsCandidate() {
        var model = PointerBrowserModel(); model.startEditing(); _ = model.activate("glove", valid: ["glove"])
        model.assigned(to: 3); #expect(model.focus == .slot(3)); #expect(model.candidate == "glove")
        model.finishEditing(); #expect(!model.editing && model.candidate == nil && model.focus == .edit)
        model.finishEditing(); #expect(!model.editing && model.candidate == nil && model.focus == .edit)
    }
    @Test func tabsStayConfinedAndReachAllSixSlots() {
        var model = PointerBrowserModel(); model.startEditing(); _ = model.activate("glove", valid: ["glove"])
        var visited: [PointerBrowserModel.Focus] = []
        for _ in 0..<11 { model.tab(backward: false, hasResults: true); visited.append(model.focus) }
        #expect(visited.contains(.editorDone))
        for i in 0..<6 { #expect(visited.contains(.slot(i))) }
        #expect(model.focus == .grid)
        model.focus = .search; model.tab(backward: true, hasResults: true); #expect(model.focus == .slot(5))
        model.finishEditing(); model.focus = .search; model.tab(backward: true, hasResults: false); #expect(model.focus == .edit)
    }
    @Test func accessibleAssignmentIncludesCandidateDestinationAndReplacement() {
        let model = PointerBrowserModel()
        #expect(model.assignmentName(candidateName: "Presentation pointer", slot: 4, replacedName: "Robot") == "Use Presentation pointer in Southwest Quick controls slot, replacing Robot")
    }
}

@Suite("Clear recovery revision lifetime")
struct ClearRecoveryModelTests {
    private let style = AnnotationStyle(color: AnnotationColor(NSColor.red.cgColor), width: 4, opacity: 1, smoothing: .off)
    @Test func clearIsOneCheckpointAndUndoRestoresTheWholeDocument() {
        var doc = AnnotationDocument()
        doc.append(Annotation(shape: .text("A", .zero), style: style)); doc.append(Annotation(shape: .number(1, .zero), style: style))
        let original = doc.annotations, before = doc.revision
        doc.clear(); #expect(doc.annotations.isEmpty && doc.revision != before)
        let cleared = doc.revision; doc.undo(); #expect(doc.annotations == original && doc.revision != cleared)
        doc.redo(); #expect(doc.annotations.isEmpty && doc.revision != cleared)
    }
    @Test func noOpChangesKeepRevision() {
        var doc = AnnotationDocument(); let revision = doc.revision
        doc.clear(); doc.undo(); doc.redo(); #expect(doc.revision == revision)
    }
    @Test func revisionIdentityIsUniqueAcrossDocumentsAndReset() {
        var doc = AnnotationDocument(); let other = AnnotationDocument()
        #expect(doc.revision != other.revision)
        let before = doc.revision; doc.reset(); #expect(doc.revision != before)
    }
    @Test func recoveryLivesUntilEditOrDismissAndStaleUndoFails() {
        var recovery = ClearRecoveryState(); let cleared = UUID()
        recovery.cleared(at: cleared); recovery.documentChanged(to: cleared)
        #expect(recovery.visible && recovery.canUndo(at: cleared))
        recovery.documentChanged(to: UUID()); #expect(!recovery.valid && !recovery.canUndo(at: cleared))
        recovery.cleared(at: cleared); recovery.dismiss(); #expect(!recovery.valid)
    }
    @Test func captureHidesWithoutExpiringAndLaterEditPreventsRestoration() {
        var recovery = ClearRecoveryState(); let revision = UUID()
        recovery.cleared(at: revision); recovery.hideForCapture(true)
        #expect(recovery.valid && !recovery.visible)
        recovery.hideForCapture(false); #expect(recovery.visible)
        recovery.hideForCapture(true); recovery.documentChanged(to: UUID()); recovery.hideForCapture(false)
        #expect(!recovery.visible && !recovery.valid)
    }
    @Test func captureRequiresHideThenCompositorDrain() {
        var capture = CaptureExclusionState()
        #expect(!capture.canCapture); capture.compositorDrained(); #expect(!capture.canCapture)
        capture.begin(windowIDs: [11, 12, 13]); #expect(capture.phase == .hidden && !capture.canCapture)
        #expect(capture.windowIDs == [11, 12, 13]); capture.compositorDrained(); #expect(capture.canCapture)
        capture.finish(); #expect(!capture.canCapture && capture.phase == .finished)
    }
}

@Suite("Quick controls shared row identity")
struct QuickControlsRowIdentityTests {
    @Test func pointerGroupAndFavoriteUseArtwork() {
        let pointer = RadialItem(id: "pointer", role: .root(.pointer), title: "Pointer", symbol: "hand.point.up")
        let favorite = RadialItem(id: "robot", role: .pointerFavorite("robot"), title: "Robot", symbol: "questionmark", style: .robot)
        #expect(RadialVisualIdentity.resolve(pointer, pointer: .glove, ink: .match, tool: .pen, list: true) == .pointer(.glove))
        #expect(RadialVisualIdentity.resolve(favorite, pointer: .glove, ink: .match, tool: .pen, list: true) == .pointer(.robot))
    }
    @Test(arguments: InkChoice.allCases) func everyInkRowUsesItsChip(_ ink: InkChoice) {
        let item = RadialItem(id: ink.rawValue, role: .ink(ink), title: ink.title, symbol: "paintpalette")
        #expect(RadialVisualIdentity.resolve(item, pointer: .glove, ink: .match, tool: .pen, list: true) == .ink(ink))
    }
    @Test func colorGroupAndInteractAndListBack() {
        let color = RadialItem(id: "color", role: .root(.color), title: "Color", symbol: "paintpalette")
        #expect(RadialVisualIdentity.resolve(color, pointer: .glove, ink: .black, tool: .pen) == .symbol("paintpalette"))
        var interact = RadialItem(id: "interact", role: .root(.interact), title: "Interact", symbol: "cursorarrow")
        #expect(RadialVisualIdentity.rowState(interact) == ""); interact.selected = true; #expect(RadialVisualIdentity.rowState(interact) == "✓")
        let back = RadialItem(id: "back", role: .back, title: "Back", symbol: "arrow.up")
        #expect(RadialVisualIdentity.resolve(back, pointer: .glove, ink: .match, tool: .pen, list: true) == .symbol("arrow.left"))
    }
}

@Suite("Quick controls lifetime integration")
struct QuickControlsLifetimeTests {
    @Test func onlyRealDocumentEditsExpireRecovery() {
        let ink = Ink(); var edits: [UUID] = []
        ink.onEdited = { edits.append($0) }
        ink.clear(); ink.undo(); ink.redo(); ink.cancel(); #expect(edits.isEmpty)
        ink.addText("Recovery", at: .zero, width: 4); #expect(edits.count == 1)
        ink.clear(); #expect(edits.count == 2)
        ink.undo(); #expect(edits.count == 3)
        ink.redo(); #expect(edits.count == 4)
        ink.begin(at: .zero, width: 4); ink.end(); #expect(edits.count == 4)
    }
    @Test func captureClosesSessionAndDrainsOwnedKeyPairsWithoutRestoration() throws {
        let input = RadialInput(nativeKeyState: { _ in false }, scheduleHold: { _, _ in })
        input.configure(trigger: nil, eligible: true)
        _ = try #require(input.openPersistent(at: .zero))
        let down = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true))
        let up = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: false))
        #expect(input.handle(.keyDown, event: down, dragging: false))
        input.setCaptureSuspended(true); input.configure(trigger: nil, eligible: false)
        #expect(input.currentSessionID == nil && input.diagnostics["open"] as? Bool == false)
        #expect(input.handle(.keyUp, event: up, dragging: false)); #expect(!input.hasOwnedInput)
        #expect(!input.handle(.keyDown, event: down, dragging: false))
        input.configure(trigger: nil, eligible: true); input.setCaptureSuspended(false)
        #expect(input.currentSessionID == nil && input.diagnostics["open"] as? Bool == false)
    }
}
