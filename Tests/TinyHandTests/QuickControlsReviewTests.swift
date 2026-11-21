import AppKit
import Testing
@testable import TinyHand

@Suite("Quick controls review regressions") @MainActor
struct QuickControlsReviewTests {
    private func session() -> RadialSession {
        RadialSession(geometry: RadialGeometry(cursor: CGPoint(x: 500, y: 500), bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000)),
                      root: [RadialItem(id: "more", role: .root(.more), title: "More", symbol: "ellipsis", group: "more"), RadialItem(id: "undo", role: .root(.undo), title: "Undo", symbol: "arrow.uturn.backward", request: ["operation": "undo"])],
                      groups: ["more": [RadialItem(id: "off", role: .more(.off), title: "Pointer off", symbol: "power", request: ["operation": "off"])]])
    }
    @Test func retainedAccessibilityActionsCannotChangeMeaningAcrossLevelsOrReset() throws {
        let ax = RadialAccessibility(), view = NSView()
        var model = session(), activations = 0, inspections = 0
        func update() {
            ax.update(session: model, view: view, frames: [], currentSession: { model }, activate: { _ in activations += 1; return true }, inspect: { _ in inspections += 1 }, back: {})
        }
        update()
        let stale = try #require(view.accessibilityChildren()?[1] as? RadialAccessibility.Item)
        _ = model.activate(0); update()
        #expect(!stale.accessibilityPerformPress())
        stale.setAccessibilityFocused(true)
        #expect(activations == 0 && inspections == 0)
        let child = try #require(view.accessibilityChildren()?.first as? RadialAccessibility.Item)
        ax.reset()
        #expect(!child.accessibilityPerformPress())
        #expect(!child.isAccessibilityElement() && child.isAccessibilityHidden() && !child.isAccessibilityEnabled())
        #expect(view.accessibilityChildren()?.isEmpty != false)
    }
    @Test func accessibilityValidatesLiveGenerationBeforeAnotherUpdate() throws {
        let ax = RadialAccessibility(), view = NSView()
        var model = session(), count = 0
        ax.update(session: model, view: view, frames: [], currentSession: { model }, activate: { _ in count += 1; return true }, inspect: { _ in count += 1 }, back: {})
        let old = try #require(view.accessibilityChildren()?[1] as? RadialAccessibility.Item)
        #expect(old.identity?.itemID == "undo" && old.identity?.generation == model.generation)
        model = session()
        #expect(!old.accessibilityPerformPress() && !old.isAccessibilityElement())
        old.setAccessibilityFocused(true); #expect(count == 0)
    }
    @Test func accessibilityUsesFrozenSlotWhenIDsCollide() throws {
        let ax = RadialAccessibility(), view = NSView()
        var model = RadialSession(geometry: session().geometry,
            root: [RadialItem(id: "pointer", role: .root(.pointer), title: "Pointer", symbol: "hand", group: "pointer")],
            groups: ["pointer": [RadialItem(id: "all", role: .allPointers, title: "All pointers…", symbol: "square.grid.2x2"),
                                  RadialItem(id: "all", role: .pointerFavorite("all"), title: "Missing all", symbol: "questionmark", enabled: false)]])
        _ = model.activate(0)
        var activated: [Int] = [], inspected: [Int] = []
        ax.update(session: model, view: view, frames: [], currentSession: { model }, activate: { activated.append($0); return true }, inspect: { inspected.append($0) }, back: {})
        let browser = try #require(view.accessibilityChildren()?[1] as? RadialAccessibility.Item)
        let missing = try #require(view.accessibilityChildren()?[2] as? RadialAccessibility.Item)
        #expect(!missing.isAccessibilityEnabled())
        #expect(!missing.accessibilityPerformPress())
        missing.setAccessibilityFocused(true)
        #expect(activated.isEmpty && inspected == [2], "Missing slot must never target the browser slot")
        #expect(browser.accessibilityPerformPress() && activated == [1])
        model = session()
        #expect(!missing.accessibilityPerformPress())
        missing.setAccessibilityFocused(true)
        #expect(inspected == [2])
    }

    @Test func listAccessibilityTracksRealClipGeometryForAllScrollSources() throws {
        var model = RadialSession(geometry: RadialGeometry(cursor: CGPoint(x: 160, y: 90), bounds: CGRect(x: 0, y: 0, width: 320, height: 180)), root: (0..<12).map { RadialItem(id: "item-\($0)", role: .placeholder, title: "Item \($0)", symbol: "circle") }, groups: [:], mode: .persistent)
        let list = QuickControlsList(frame: CGRect(origin: .zero, size: model.panelFrame.size)), ax = RadialAccessibility()
        var updates = 0
        list.onScroll = { offset in
            updates += 1; model.scrollList(to: offset)
            let actual = list.semanticGeometry
            ax.refreshFrames(view: list, frames: actual.frames, visibility: actual.visible)
        }
        list.update(model, tokens: RadialAppearance()); list.layoutSubtreeIfNeeded()
        let geometry = list.semanticGeometry
        #expect(geometry.visible.first == true && geometry.visible.last == false)
        ax.update(session: model, view: list, frames: geometry.frames, visibility: geometry.visible, currentSession: { model }, activate: { _ in true }, inspect: { _ in }, back: {})
        let first = try #require(list.accessibilityChildren()?.first as? RadialAccessibility.Item)
        let last = try #require(list.accessibilityChildren()?.last as? RadialAccessibility.Item)
        #expect(!first.isAccessibilityHidden() && last.isAccessibilityHidden())
        #expect(list.accessibilityVisibleChildren()?.contains(where: { ($0 as? RadialAccessibility.Item) === first }) == true)
        #expect(list.accessibilityVisibleChildren()?.contains(where: { ($0 as? RadialAccessibility.Item) === last }) == false)
        model.inspect(11, keyboard: true); list.update(model, tokens: RadialAppearance())
        #expect(first.isAccessibilityHidden() && !last.isAccessibilityHidden())
        #expect(list.accessibilityVisibleChildren()?.contains(where: { ($0 as? RadialAccessibility.Item) === last }) == true)
        let scroll = try #require(list.subviews.compactMap { $0 as? NSScrollView }.first)
        // Clip-view bounds notifications are shared by wheel and programmatic movement.
        scroll.contentView.scroll(to: .zero); scroll.reflectScrolledClipView(scroll.contentView)
        #expect(!first.isAccessibilityHidden() && last.isAccessibilityHidden())
        #expect(updates > 1)
        for frame in list.semanticGeometry.frames where !frame.isEmpty { #expect(list.bounds.contains(frame)) }
    }
}

@Suite("Quick controls input and responder regressions") @MainActor
struct QuickControlsInputReviewTests {
    private func key(_ flags: NSEvent.ModifierFlags) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: "z", charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6))
    }
    @Test func persistentOpeningInstallsAndEnablesTapWithNoHoldAssignment() throws {
        var enabled = false, operations: [String] = []
        let input = RadialInput(nativeKeyState: { _ in false }, scheduleHold: { _, _ in })
        let tap = InputTap(sessionLocked: { false }, radial: input, installation: .init(install: { operations.append("install"); return true }, isEnabled: { enabled }, setEnabled: {
            if $0 { #expect(input.currentSessionID == nil, "Enable before queuing any open event") }
            enabled = $0; operations.append($0 ? "enable" : "disable")
        }))
        tap.configureRadial(trigger: nil, eligible: true)
        #expect(!tap.isInstalled)
        let id = try #require(tap.openQuickControls(at: .zero))
        #expect(operations == ["install", "enable"] && enabled && tap.isInstalled)
        var failures = 0
        #expect(tap.openQuickControls(at: .zero, onConnectionFailure: { failures += 1 }) == nil)
        #expect(failures == 0, "Busy controls must not show a permission error")
        let down = try #require(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 2000, y: 2000), mouseButton: .left))
        let up = try #require(CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: down.location, mouseButton: .left))
        #expect(tap.handle(type: .leftMouseDown, event: down) == nil)
        input.end(sessionID: id); tap.configureRadial(trigger: nil, eligible: false)
        #expect(enabled, "The owned outside dismissal release keeps the tap alive")
        #expect(tap.handle(type: .leftMouseUp, event: up) == nil)
        #expect(!enabled && !input.hasOwnedInput)
    }
    @Test func queuedActivationCannotReachAClosedOrReplacementInputSession() async throws {
        let input = RadialInput(nativeKeyState: { _ in false }, scheduleHold: { _, _ in })
        input.configure(trigger: nil, eligible: true)
        let first = try #require(input.openPersistent(at: .zero))
        var keys = 0
        input.onEvent = { _, event in if case .key = event { keys += 1 } }
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        let enter = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true))
        #expect(input.handle(.keyDown, event: enter, dragging: false))
        input.end(sessionID: first)
        enter.type = .keyUp; #expect(input.handle(.keyUp, event: enter, dragging: false))
        let second = try #require(input.openPersistent(at: .zero))
        #expect(second != first)
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        #expect(keys == 0)
        #expect(input.currentSessionID == second)
        input.end(sessionID: second)
    }

    @Test(arguments: [false, true]) func failedTapInstallationOrEnableNeverOpensControls(installs: Bool) {
        let input = RadialInput(nativeKeyState: { _ in false }, scheduleHold: { _, _ in })
        let tap = InputTap(radial: input, installation: .init(install: { installs }, isEnabled: { false }, setEnabled: { _ in }))
        tap.configureRadial(trigger: nil, eligible: true)
        var failures = 0
        #expect(tap.openQuickControls(at: .zero, onConnectionFailure: { failures += 1 }) == nil)
        #expect(failures == 1)
        #expect(input.currentSessionID == nil && input.diagnostics["open"] as? Bool == false)
    }
    @Test func responderSelectorsAndStandardEquivalentsReachInkHistory() throws {
        let ink = Ink(), responder = AnnotationUndoResponder()
        ink.addText("Scoped undo", at: .zero, width: 4)
        responder.canUndo = { ink.canUndo }; responder.canRedo = { ink.canRedo }
        responder.onUndo = { ink.undo() }; responder.onRedo = { ink.redo() }
        let first = NSResponder(); first.nextResponder = responder
        #expect(first.tryToPerform(#selector(AnnotationUndoResponder.undo(_:)), with: nil))
        #expect(ink.count == 0 && ink.canRedo)
        #expect(responder.performKeyEquivalent(with: try key([.command, .shift]), firstResponder: NSResponder()))
        #expect(ink.count == 1)
        #expect(responder.performKeyEquivalent(with: try key(.command), firstResponder: NSResponder()))
        #expect(ink.count == 0)
        let menu = NSMenuItem(title: "Redo", action: #selector(AnnotationUndoResponder.redo(_:)), keyEquivalent: "z")
        #expect(responder.validateMenuItem(menu))
    }
    @Test func searchFieldsAndModifiedNonstandardChordsKeepNativeUndo() throws {
        let responder = AnnotationUndoResponder(); var undo = 0
        responder.canUndo = { true }; responder.onUndo = { undo += 1 }
        #expect(!responder.performKeyEquivalent(with: try key(.command), firstResponder: NSTextView()))
        #expect(!responder.performKeyEquivalent(with: try key(.command), firstResponder: NSSearchField()))
        #expect(!responder.performKeyEquivalent(with: try key([.command, .option]), firstResponder: NSResponder()))
        #expect(undo == 0)
    }
    @Test func interactDoesNotCaptureExternalCommandZ() throws {
        let tap = InputTap(sessionLocked: { false }, radial: RadialInput(nativeKeyState: { _ in false }, scheduleHold: { _, _ in }))
        tap.setActive(false)
        let down = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 6, keyDown: true)); down.flags = .maskCommand
        let up = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 6, keyDown: false)); up.flags = .maskCommand
        #expect(tap.handle(type: .keyDown, event: down) != nil && tap.handle(type: .keyUp, event: up) != nil)
    }
    @Test func focusedHeldControlsKeepUndoChordsAndRecoveryKeysNative() throws {
        let input = RadialInput(nativeKeyState: { _ in false }, scheduleHold: { _, _ in })
        input.configure(trigger: .option, eligible: true)
        let flags = try #require(CGEvent(source: nil)); flags.flags = .maskAlternate
        _ = input.handle(.flagsChanged, event: flags, dragging: false)
        input.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        input.setKeyboardFocus(true)
        flags.flags = [.maskAlternate, .maskCommand]; _ = input.handle(.flagsChanged, event: flags, dragging: false)
        let undo = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 6, keyDown: true)); undo.flags = [.maskAlternate, .maskCommand]
        #expect(!input.handle(.keyDown, event: undo, dragging: false))
        #expect(input.diagnostics["open"] as? Bool == true)
        input.configureNativeSurface(region: CGRect(x: 0, y: 0, width: 100, height: 100), ownsFocus: true)
        let enter = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true))
        #expect(!input.handle(.keyDown, event: enter, dragging: false))
        let mouse = try #require(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 20, y: 20), mouseButton: .left))
        #expect(!input.handle(.leftMouseDown, event: mouse, dragging: false))
        mouse.location = CGPoint(x: 500, y: 500)
        #expect(input.handle(.leftMouseDown, event: mouse, dragging: false))
    }
    @Test func captureClosesHeldSessionAndDrainsBothMouseAndKeyPairs() throws {
        let input = RadialInput(nativeKeyState: { _ in false }, scheduleHold: { _, _ in })
        input.configure(trigger: .option, eligible: true)
        let flags = try #require(CGEvent(source: nil)); flags.flags = .maskAlternate
        _ = input.handle(.flagsChanged, event: flags, dragging: false)
        input.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        let key = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 48, keyDown: true)); key.flags = .maskAlternate
        let click = try #require(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left))
        #expect(input.handle(.keyDown, event: key, dragging: false))
        #expect(input.handle(.leftMouseDown, event: click, dragging: false))
        input.setCaptureSuspended(true)
        #expect(input.currentSessionID == nil && input.diagnostics["open"] as? Bool == false)
        key.type = .keyUp; click.type = .leftMouseUp
        #expect(input.handle(.keyUp, event: key, dragging: false))
        #expect(input.handle(.leftMouseUp, event: click, dragging: false))
        input.setCaptureSuspended(false)
        #expect(!input.hasOwnedInput && input.currentSessionID == nil)
    }
}

@Suite("Quick controls error and name regressions")
struct QuickControlsFeedbackReviewTests {
    @Test func rejectionsKeepReasonAndOfferAppropriateRecovery() {
        let response: [String: Any] = ["ok": false, "error": ["code": "accessibility", "message": "Allow Accessibility to draw."]]
        let result = QuickCommandResult.bridge(response, operation: "tool")
        #expect(result == .failure(.rejected(operation: "tool", code: "accessibility", reason: "Allow Accessibility to draw.")))
        if case .failure(let failure) = result { #expect(failure.recovery == .accessibility && failure.reason == "Allow Accessibility to draw.") }
        else { Issue.record("Rejection became success") }
        #expect(QuickCommandResult.bridge(["ok": true], operation: "capture") == .success)
        if case .failure(let failure) = QuickCommandResult.bridge([:], operation: "capture") { #expect(!failure.reason.isEmpty && failure.recovery == .settings) }
        else { Issue.record("Malformed bridge response became success") }
    }
    @Test func errorsPersistAndAnnounceOnceUntilDismissed() {
        var state = QuickCommandErrorState()
        let failure = QuickCommandFailure.capture(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError))
        #expect(failure.recovery == .captureFolder && failure.title == "Couldn't save screenshot")
        let first = state.present(failure), repeatAnnouncement = state.present(failure)
        #expect(first && !repeatAnnouncement && state.failure == failure)
        state.dismiss(); #expect(state.failure == nil)
        let afterDismiss = state.present(failure); #expect(afterDismiss)
        #expect(QuickCommandFailure.capture(ScreenshotError.permission).recovery == .screenRecording)
        #expect(QuickCommandFailure.capture(ScreenshotError.timeout).recovery == .retryScreenshot)
    }
    @Test(arguments: ["Presentation pointer", "Supercalifragilisticexpialidocious pointer", "Glove", "A very long custom pointer name"]) func measuredNamesKeepNativeTypeAndTwoLines(_ title: String) {
        let lines = PointerBrowserNameLayout.lines(title)
        #expect(lines.count <= 2 && !lines.isEmpty)
        for line in lines {
            let ink = (line as NSString).boundingRect(with: CGSize(width: 1000, height: 100), options: .usesDeviceMetrics, attributes: [.font: PointerBrowserNameLayout.font])
            #expect(ink.width <= 64)
        }
        #expect(PointerBrowserNameLayout.font.pointSize == 11 && PointerBrowserNameLayout.leading == 14)
        if title == "Presentation pointer" { #expect(lines.joined().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "") == "Presentationpointer") }
    }
    @Test func browserNamesUseTheFullCellAndReadableWordBreaks() {
        #expect(PointerBrowserNameLayout.lines("Gingerbread") == ["Gingerbread"])
        #expect(PointerBrowserNameLayout.lines("Presentation") == ["Presenta-", "tion"])
        #expect(PointerBrowserNameLayout.lines("Presentation pointer") == ["Presenta-", "tion pointer"])
        #expect(PointerBrowserNameLayout.lines("Super\u{AD}longword") == ["Super-", "longword"])
        #expect(PointerBrowserNameLayout.lines("Super\u{AD}longword", width: 100) == ["Superlongword"])
        let inkWidth = ("Gingerbread" as NSString).boundingRect(with: CGSize(width: 1000, height: 100), options: .usesDeviceMetrics, attributes: [.font: PointerBrowserNameLayout.font]).width
        #expect(PointerBrowserNameLayout.lines("Gingerbread", width: inkWidth) == ["Gingerbread"])
        #expect(PointerBrowserNameLayout.lines("Gingerbread", width: inkWidth - 1) == ["Ginger-", "bread"])
    }
}
