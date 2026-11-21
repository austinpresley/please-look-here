import AppKit
import Testing
@testable import TinyHand

@Suite("Quick controls focus ownership", .serialized) @MainActor
struct QuickControlsFocusTests {
    private final class ResponderView: NSView {
        override var acceptsFirstResponder: Bool { true }
    }
    @MainActor private final class FocusProbe {
        var current: QuickControlsFocus.Context
        var appActive = true
        var captures = 0
        var restored: [QuickControlsFocus.Context] = []
        var delayActivation = false
        var pendingActivation: QuickControlsFocus.Context?
        var onRestore: (() -> Void)?
        init(_ context: QuickControlsFocus.Context) { current = context }
        var driver: QuickControlsFocus {
            QuickControlsFocus(capture: { self.captures += 1; return self.current }, focus: { window, responder, _ in
                window.orderFrontRegardless()
                window.makeFirstResponder(responder)
                self.current = .init(app: .current, window: window, responder: window.firstResponder)
                return true
            }, isKey: { self.current.window === $0 }, isActive: { self.appActive }, restore: { context in
                self.onRestore?(); self.restored.append(context)
                if self.delayActivation { self.pendingActivation = context; return }
                self.current = context
                context.window?.makeFirstResponder(context.responder)
            })
        }
        func completeActivation() {
            guard let context = pendingActivation else { return }
            pendingActivation = nil; current = context
            context.window?.makeFirstResponder(context.responder)
        }
    }
    @MainActor private final class Fixture {
        let originalWindow: NSWindow
        let originalResponder = ResponderView()
        let originalApp: NSRunningApplication
        let probe: FocusProbe
        let overlay: OverlayController
        let input = RadialInput(nativeKeyState: { _ in false }, scheduleHold: { _, _ in })
        var events: [String] = []
        init() throws {
            _ = NSApplication.shared
            Preferences.radialTrigger = .option; Preferences.pointerMode = .point
            originalApp = try #require(NSWorkspace.shared.runningApplications.first { $0.processIdentifier != getpid() && !$0.isTerminated })
            originalWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 200, height: 100), styleMask: .titled, backing: .buffered, defer: false)
            originalWindow.isReleasedWhenClosed = false; originalWindow.contentView = originalResponder
            originalWindow.makeFirstResponder(originalResponder)
            probe = FocusProbe(.init(app: originalApp, window: originalWindow, responder: originalResponder))
            overlay = OverlayController(accessibility: { false }, screenRecording: { false }, requestRecording: {}, quickControlsFocus: probe.driver)
            let onFocus = overlay.radial.onFocusOwnershipChanged
            overlay.radial.onFocusOwnershipChanged = { [weak self] value in onFocus?(value); self?.input.setKeyboardFocus(value) }
            let onContext = overlay.clearRecovery.onContextChanged
            overlay.clearRecovery.onContextChanged = { [weak self] in
                onContext?()
                guard let self else { return }
                self.input.configureNativeSurface(region: nil, ownsFocus: self.overlay.clearRecovery.ownsKeyboardFocus)
            }
            let onClose = overlay.radial.onClose
            overlay.radial.onClose = { [weak self] id in onClose?(id); self?.input.end(sessionID: id) }
            input.onEvent = { [weak self] id, event in
                guard let self else { return }
                switch event {
                case .open, .persistentOpen:
                    let persistent: Bool
                    if case .persistentOpen = event { persistent = true } else { persistent = false }
                    self.overlay.radial.open(sessionID: id, at: CGPoint(x: 500, y: 400), style: .laser, mode: .point, canUndo: self.overlay.canUndo, canRedo: self.overlay.canRedo, hasInk: false, invocation: persistent ? .persistent : .held, bounds: CGRect(x: 0, y: 0, width: 1200, height: 800))
                case .key(let key, let modifiers): self.overlay.radial.key(key, modifiers: modifiers, sessionID: id)
                case .cancel: self.events.append("cancel"); self.overlay.radial.close(sessionID: id)
                case .focusLost: self.overlay.radial.cancelForFocusLoss(sessionID: id)
                case .release: self.events.append("release"); self.overlay.radial.release(sessionID: id)
                case .click(let point): self.overlay.radial.click(at: point, sessionID: id)
                default: Issue.record("Unexpected focus-fixture input")
                }
            }
            overlay.seedClearRecovery()
        }
        func close() {
            overlay.radial.closeImmediately(); overlay.clearRecovery.dismissRecovery(); overlay.deactivate(); originalWindow.close()
        }
        func flags(_ flags: CGEventFlags) throws {
            let event = try #require(CGEvent(source: nil)); event.flags = flags
            #expect(!input.handle(.flagsChanged, event: event, dragging: false))
        }
        func open(_ persistent: Bool, keyboard: Bool = true) async throws {
            input.configure(trigger: .option, eligible: true)
            if persistent { #expect(input.openPersistent(at: CGPoint(x: 500, y: 400)) != nil) }
            else {
                try flags(.maskAlternate)
                input.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
            }
            await QuickControlsFocusTests.drain()
            #expect(overlay.radial.session != nil)
            guard keyboard else { return }
            let tab = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 48, keyDown: true)); tab.flags = persistent ? [] : .maskAlternate
            #expect(input.handle(.keyDown, event: tab, dragging: false))
            await QuickControlsFocusTests.drain()
            tab.type = .keyUp; #expect(input.handle(.keyUp, event: tab, dragging: false))
            #expect(probe.current.window === overlay.radial.window)
        }
        func focusRecovery(_ persistent: Bool) throws {
            let flags: NSEvent.ModifierFlags = persistent ? [.command, .shift] : [.option, .command, .shift]
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: overlay.radial.window.windowNumber, context: nil, characters: "u", charactersIgnoringModifiers: "u", isARepeat: false, keyCode: 32))
            // This is the real panel override and OverlayController-installed route.
            #expect(overlay.radial.window.performKeyEquivalent(with: event))
            #expect(probe.current.window === overlay.clearRecovery.window)
        }
        func chooseAllPointers() throws {
            let id = try #require(input.currentSessionID)
            overlay.radial.key(.number(1), modifiers: [], sessionID: id)
            overlay.radial.key(.enter, modifiers: [], sessionID: id)
            #expect(overlay.radial.session?.group == "pointer")
            for _ in 0..<8 {
                if overlay.radial.session?.inspected?.opensBrowser == true { break }
                overlay.radial.key(.tab, modifiers: [], sessionID: id)
            }
            #expect(overlay.radial.session?.inspected?.opensBrowser == true)
            overlay.radial.key(.enter, modifiers: [], sessionID: id)
            #expect(overlay.radial.session == nil)
        }
        func expectOriginalRestoredOnce(captures: Int = 1) {
            #expect(probe.restored.count == 1)
            #expect(probe.restored.first?.app === originalApp)
            #expect(probe.restored.first?.window === originalWindow)
            #expect(probe.restored.first?.responder === originalResponder)
            #expect(probe.current.window === originalWindow && originalWindow.firstResponder === originalResponder)
            #expect(probe.captures == captures, "Only wheel openings should capture a context")
        }
    }
    private static func drain() async {
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }
    private func drain() async { await Self.drain() }


    @Test(arguments: ["release", "click"], [false, true])
    func heldCompletionChecksFocusBeforeDelayedNotification(route: String, activationOnly: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(false)
        let id = try #require(fixture.input.currentSessionID)
        fixture.overlay.radial.updateHistory(canUndo: true, canRedo: true, hasInk: true)
        fixture.overlay.radial.key(.number(4), modifiers: [], sessionID: id)
        var commands = 0
        fixture.overlay.radial.perform = { _ in commands += 1; return .success }
        let point = RadialGeometry.point(angle: 135, radius: 100, center: try #require(fixture.overlay.radial.session).geometry.center)
        if route == "release" { try fixture.flags([]) }
        else {
            let click = try #require(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left))
            #expect(fixture.input.handle(.leftMouseDown, event: click, dragging: false))
        }
        if activationOnly { fixture.probe.appActive = false }
        else { fixture.probe.current = .init(app: fixture.originalApp, window: fixture.originalWindow, responder: fixture.originalResponder) }
        await drain()
        #expect(commands == 0 && fixture.overlay.radial.session == nil)
        #expect(fixture.probe.restored.isEmpty)
        if route == "click" {
            let up = try #require(CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left))
            #expect(fixture.input.handle(.leftMouseUp, event: up, dragging: false))
        }
        #expect(!fixture.input.hasOwnedInput)
    }

    @Test func keyboardOwnedHoldRevokesQueuedActivationOnCommandTab() async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(false)
        let id = try #require(fixture.input.currentSessionID)
        fixture.overlay.radial.updateHistory(canUndo: true, canRedo: true, hasInk: true)
        fixture.overlay.radial.key(.number(4), modifiers: [], sessionID: id)
        var commands = 0
        fixture.overlay.radial.perform = { _ in commands += 1; return .success }
        let enter = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true)); enter.flags = .maskAlternate
        #expect(fixture.input.handle(.keyDown, event: enter, dragging: false))
        let tab = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 48, keyDown: true)); tab.flags = [.maskAlternate, .maskCommand]
        #expect(!fixture.input.handle(.keyDown, event: tab, dragging: false))
        #expect(fixture.input.currentSessionID == nil, "Revoke before queued Clear reaches the main queue")
        tab.type = .keyUp; #expect(!fixture.input.handle(.keyUp, event: tab, dragging: false))
        await drain()
        #expect(commands == 0 && fixture.overlay.radial.session == nil && fixture.probe.restored.isEmpty)
        enter.type = .keyUp; #expect(fixture.input.handle(.keyUp, event: enter, dragging: false))
        #expect(!fixture.input.hasOwnedInput)
    }

    @Test(arguments: ["release", "click", "activation"])
    func pointerOnlyHoldStillWorksWithExternalAppFrontmost(route: String) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(false, keyboard: false)
        let id = try #require(fixture.input.currentSessionID)
        fixture.overlay.radial.updateHistory(canUndo: true, canRedo: true, hasInk: true)
        let point = RadialGeometry.point(angle: 135, radius: 100, center: try #require(fixture.overlay.radial.session).geometry.center)
        fixture.overlay.radial.move(to: point, sessionID: id)
        var commands = 0
        fixture.overlay.radial.perform = { _ in commands += 1; return .success }
        if route == "activation" {
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: fixture.originalApp])
            #expect(fixture.overlay.radial.session != nil)
        }
        if route == "click" { fixture.overlay.radial.click(at: point, sessionID: id) }
        else { fixture.overlay.radial.release(sessionID: id) }
        #expect(commands == 1 && fixture.overlay.radial.session == nil && fixture.probe.restored.isEmpty)
    }

    @Test(arguments: [false, true])
    func settingsOwnsRestorationUntilCloseDespiteDelayedActivation(reopen: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        let settings = SettingsWindow(focus: fixture.probe.driver)
        defer { settings.window?.close() }
        let app = AppDelegate(overlay: fixture.overlay, settings: settings)
        defer { withExtendedLifetime(app) {} }
        fixture.overlay.radial.perform = { _ in Issue.record("Settings must use the restoration handoff"); return .success }
        try await fixture.open(true)
        fixture.probe.delayActivation = true
        let id = try #require(fixture.input.currentSessionID)
        fixture.overlay.radial.key(.number(8), modifiers: [], sessionID: id)
        fixture.overlay.radial.key(.enter, modifiers: [], sessionID: id)
        for _ in 0..<6 {
            if fixture.overlay.radial.session?.inspected?.id == "settings" { break }
            fixture.overlay.radial.key(.tab, modifiers: [], sessionID: id)
        }
        fixture.overlay.radial.key(.enter, modifiers: [], sessionID: id)
        let window = try #require(settings.window)
        #expect(fixture.probe.restored.isEmpty && fixture.probe.pendingActivation == nil)
        fixture.probe.completeActivation()
        #expect(fixture.probe.current.window === window)
        if reopen { settings.show(.shortcuts) }
        settings.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))
        #expect(fixture.probe.restored.count == 1)
        fixture.probe.completeActivation()
        fixture.expectOriginalRestoredOnce()
        settings.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))
        #expect(fixture.probe.restored.count == 1)
        await drain()
    }


    @Test(arguments: [false, true])
    func commandPreparationUsesOperationRatherThanItemID(capture: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(true)
        let id = try #require(fixture.input.currentSessionID)
        var prepared: [String] = []
        fixture.overlay.radial.onWillPerform = { operation, _ in prepared.append(operation) }
        fixture.overlay.radial.perform = { _ in .success }
        fixture.overlay.radial.key(.number(capture ? 6 : 1), modifiers: [], sessionID: id)
        if !capture {
            fixture.overlay.radial.key(.enter, modifiers: [], sessionID: id)
            for _ in 0..<8 {
                if fixture.overlay.radial.session?.inspected?.id == "laser" { break }
                fixture.overlay.radial.key(.tab, modifiers: [], sessionID: id)
            }
        }
        fixture.overlay.radial.key(.enter, modifiers: [], sessionID: id)
        #expect(prepared == [capture ? "capture" : "style"])
    }

    @Test(arguments: ["commandTab", "key", "app", "externalActivation", "space", "lock", "sleep", "tapLock"])
    func unexpectedFocusLossCancelsWithoutRestoringAndDrainsOwnedPairs(source: String) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(true)
        fixture.overlay.radial.updateHistory(canUndo: true, canRedo: false, hasInk: true)
        let id = try #require(fixture.input.currentSessionID)
        fixture.overlay.radial.key(.number(4), modifiers: [], sessionID: id)
        #expect(fixture.overlay.radial.session?.inspected?.id == "clear")
        var commands = 0
        fixture.overlay.radial.perform = { _ in commands += 1; return .success }
        let enter = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true))
        let mouse = try #require(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left))
        #expect(fixture.input.handle(.keyDown, event: enter, dragging: false))
        #expect(fixture.input.handle(.leftMouseDown, event: mouse, dragging: false))
        // These activations are queued; ownership must be revoked before delivery.
        fixture.probe.current = .init(app: fixture.originalApp, window: fixture.originalWindow, responder: fixture.originalResponder)
        switch source {
        case "commandTab":
            let tab = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 48, keyDown: true)); tab.flags = .maskCommand
            #expect(!fixture.input.handle(.keyDown, event: tab, dragging: false))
            await drain()
        case "tapLock": fixture.input.suspendForSystem(releasingButton: nil, key: nil); await drain()
        case "key": NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: fixture.overlay.radial.window)
        case "app": NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        case "externalActivation": NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: fixture.originalApp])
        case "space": NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        case "lock": NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        default: NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        }
        #expect(fixture.overlay.radial.session == nil)
        #expect(fixture.input.currentSessionID == nil)
        #expect(fixture.probe.restored.isEmpty, "The user already moved away")
        #expect(fixture.input.hasOwnedInput)
        #expect(fixture.input.handle(.keyDown, event: enter, dragging: false), "Owned repeats still drain")
        enter.type = .keyUp; mouse.type = .leftMouseUp
        #expect(fixture.input.handle(.keyUp, event: enter, dragging: false))
        #expect(fixture.input.handle(.leftMouseUp, event: mouse, dragging: false))
        #expect(!fixture.input.hasOwnedInput)
        enter.type = .keyDown
        #expect(!fixture.input.handle(.keyDown, event: enter, dragging: false), "Return in the new app stays native")
        await drain()
        #expect(commands == 0, "Queued Clear must be rejected after ownership loss")
        #expect(fixture.overlay.radial.session == nil && fixture.probe.restored.isEmpty)
        #expect(fixture.probe.current.window === fixture.originalWindow)
    }

    @Test func recoveryHandoffSurvivesItsExpectedResignThenExternalFocusCancelsWheel() async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(true); try fixture.focusRecovery(true)
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: fixture.overlay.radial.window)
        #expect(fixture.overlay.radial.session != nil, "The explicit recovery handoff is expected")
        #expect(fixture.probe.current.window === fixture.overlay.clearRecovery.window)
        #expect(fixture.probe.restored.isEmpty)
        fixture.probe.current = .init(app: fixture.originalApp, window: fixture.originalWindow, responder: fixture.originalResponder)
        fixture.overlay.clearRecovery.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: fixture.overlay.clearRecovery.window))
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: fixture.originalApp])
        #expect(fixture.overlay.radial.session == nil && fixture.input.currentSessionID == nil)
        #expect(fixture.overlay.clearRecovery.state.visible && fixture.probe.restored.isEmpty)
        let enter = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true))
        #expect(!fixture.input.handle(.keyDown, event: enter, dragging: false))
        fixture.overlay.clearRecovery.restoreDrawing()
        #expect(fixture.overlay.canRedo)
        fixture.expectOriginalRestoredOnce()
        await drain()
    }

    @Test func queuedActivationChecksNativeFocusEvenBeforeResignNotification() async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(true)
        let id = try #require(fixture.input.currentSessionID)
        fixture.overlay.radial.updateHistory(canUndo: true, canRedo: false, hasInk: true)
        fixture.overlay.radial.key(.number(4), modifiers: [], sessionID: id)
        var commands = 0
        fixture.overlay.radial.perform = { _ in commands += 1; return .success }
        let enter = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true))
        #expect(fixture.input.handle(.keyDown, event: enter, dragging: false))
        fixture.probe.current = .init(app: fixture.originalApp, window: fixture.originalWindow, responder: fixture.originalResponder)
        await drain()
        #expect(commands == 0 && fixture.overlay.radial.session == nil)
        #expect(fixture.probe.restored.isEmpty)
        enter.type = .keyUp; #expect(fixture.input.handle(.keyUp, event: enter, dragging: false))
    }

    @Test(arguments: [false, true])
    func pointerOffPreservesRecoveryAndItsUndo(inactive: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        if !inactive { #expect(fixture.overlay.activate()) }
        try await fixture.open(true); try fixture.focusRecovery(true)
        fixture.overlay.radial.closeImmediately()
        fixture.overlay.deactivate()
        #expect(fixture.overlay.clearRecovery.state.visible)
        #expect(fixture.overlay.clearRecovery.window.isVisible)
        #expect(fixture.probe.restored.isEmpty)
        fixture.overlay.clearRecovery.restoreDrawing()
        #expect(fixture.overlay.canRedo, "Recovery Undo must restore the cleared drawing after Off")
        fixture.expectOriginalRestoredOnce()
    }

    @Test func browserCloseRestoresOriginalOnceDespiteDelayedActivation() async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(true)
        fixture.probe.delayActivation = true
        try fixture.chooseAllPointers()
        #expect(fixture.probe.restored.isEmpty, "Handoff must transfer without requesting external activation")
        await drain()
        #expect(fixture.overlay.pointerBrowser.visible)
        #expect(fixture.probe.current.window === fixture.overlay.pointerBrowser.window)
        #expect(fixture.probe.restored.isEmpty)
        #expect(fixture.probe.captures == 1, "Browser must inherit the original wheel token")
        fixture.overlay.pointerBrowser.close()
        #expect(fixture.probe.restored.count == 1)
        #expect(fixture.probe.pendingActivation?.app === fixture.originalApp)
        #expect(fixture.probe.pendingActivation?.window === fixture.originalWindow)
        #expect(fixture.probe.pendingActivation?.responder === fixture.originalResponder)
        fixture.probe.completeActivation()
        fixture.expectOriginalRestoredOnce()
        fixture.overlay.pointerBrowser.close(); fixture.overlay.deactivate(); await drain()
        fixture.expectOriginalRestoredOnce()
    }

    @Test(arguments: [false, true])
    func cancelledBrowserHandoffRestoresOriginalOnce(capture: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(true); try fixture.chooseAllPointers()
        #expect(fixture.probe.restored.isEmpty)
        // Cancel while the browser Task is still pending on the main actor.
        if capture { fixture.overlay.beginCaptureExclusion() }
        else { fixture.overlay.deactivate() }
        fixture.expectOriginalRestoredOnce()
        await drain()
        #expect(!fixture.overlay.pointerBrowser.visible)
        if capture { fixture.overlay.finishCaptureExclusion() }
        fixture.overlay.pointerBrowser.close(); fixture.overlay.deactivate(); await drain()
        fixture.expectOriginalRestoredOnce()
    }

    @Test(arguments: [false, true])
    func quitConsumesFocusedRecoveryBeforeTeardownEvenWhenInactive(inactive: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        if !inactive { #expect(fixture.overlay.activate()) }
        try await fixture.open(true); try fixture.focusRecovery(true)
        fixture.overlay.radial.closeImmediately()
        #expect(fixture.probe.restored.isEmpty)
        var teardownStarted = false
        fixture.probe.onRestore = { [weak overlay = fixture.overlay] in
            #expect(!teardownStarted, "No focus activation may occur during or after teardown")
            #expect(overlay?.isActive == !inactive, "Recovery must finish before deactivation")
        }
        fixture.overlay.onActiveChanged = { teardownStarted = true }
        let delegate = AppDelegate(overlay: fixture.overlay)
        let termination = Notification(name: NSApplication.willTerminateNotification)
        delegate.applicationWillTerminate(termination)
        teardownStarted = true
        #expect(!fixture.overlay.clearRecovery.state.valid && !fixture.overlay.clearRecovery.window.isVisible)
        #expect(!fixture.overlay.isActive)
        fixture.expectOriginalRestoredOnce()
        delegate.applicationWillTerminate(termination)
        fixture.overlay.clearRecovery.dismissRecovery(); fixture.overlay.clearRecovery.hideForCapture(true)
        fixture.overlay.clearRecovery.documentChanged(to: UUID()); fixture.overlay.radial.closeImmediately()
        await drain()
        fixture.expectOriginalRestoredOnce()
        fixture.probe.onRestore = nil
    }

    @Test(arguments: [false, true])
    func heldRecoveryRefocusInSecondSessionPreservesOriginalContext(dismiss: Bool) async throws {
        try await recoveryRefocusInSecondSession(persistent: false, dismiss: dismiss)
    }
    @Test(arguments: [false, true])
    func persistentRecoveryRefocusInSecondSessionPreservesOriginalContext(dismiss: Bool) async throws {
        try await recoveryRefocusInSecondSession(persistent: true, dismiss: dismiss)
    }
    private func recoveryRefocusInSecondSession(persistent: Bool, dismiss: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(persistent); try fixture.focusRecovery(persistent)
        try fixture.flags([]); await drain()
        if persistent { fixture.overlay.radial.closeImmediately() }
        #expect(fixture.overlay.radial.session == nil)
        #expect(fixture.probe.current.window === fixture.overlay.clearRecovery.window)
        #expect(fixture.probe.restored.isEmpty)

        // Model focus leaving recovery without activating an external app. A
        // distinct second context exposes accidental replacement of the first.
        let laterResponder = ResponderView()
        let laterWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 200, height: 100), styleMask: .titled, backing: .buffered, defer: false)
        laterWindow.isReleasedWhenClosed = false; laterWindow.contentView = laterResponder
        laterWindow.makeFirstResponder(laterResponder); defer { laterWindow.close() }
        fixture.probe.current = .init(app: fixture.originalApp, window: laterWindow, responder: laterResponder)
        fixture.overlay.clearRecovery.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: fixture.overlay.clearRecovery.window))
        #expect(!fixture.overlay.clearRecovery.ownsKeyboardFocus)

        try await fixture.open(persistent); try fixture.focusRecovery(persistent)
        #expect(fixture.overlay.radial.session?.ownsFocus == false)
        fixture.overlay.radial.refresh(style: .laser, mode: .point)
        #expect(fixture.probe.current.window === fixture.overlay.clearRecovery.window)
        try fixture.flags([])
        #expect(fixture.probe.restored.isEmpty)
        await drain()
        if persistent { fixture.overlay.radial.closeImmediately() }
        #expect(fixture.overlay.radial.session == nil)
        #expect(persistent || fixture.events == ["cancel", "cancel"])
        #expect(fixture.probe.current.window === fixture.overlay.clearRecovery.window)
        #expect(fixture.probe.restored.isEmpty, "The second wheel must relinquish its restoration token")

        if dismiss { fixture.overlay.clearRecovery.dismissRecovery() }
        else {
            let button = try #require(fixture.overlay.clearRecovery.window.firstResponder as? NSButton)
            button.performClick(nil)
            #expect(fixture.overlay.canRedo, "Undo must reach production Ink history")
        }
        fixture.expectOriginalRestoredOnce(captures: 2)
        fixture.overlay.radial.closeImmediately(); fixture.overlay.clearRecovery.dismissRecovery(); await drain()
        fixture.expectOriginalRestoredOnce(captures: 2)
    }

    @Test(arguments: [false, true], [false, true])
    func recoveryKeepsFocusThroughReleaseAndQueuedClose(persistent: Bool, dismiss: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(persistent); try fixture.focusRecovery(persistent)
        try fixture.flags([])
        // A held release queues cancellation. Persistent controls close later.
        #expect(fixture.probe.restored.isEmpty)
        await drain()
        if persistent { fixture.overlay.radial.closeImmediately() }
        #expect(fixture.overlay.radial.session == nil)
        #expect(persistent || fixture.events == ["cancel"])
        #expect(fixture.probe.current.window === fixture.overlay.clearRecovery.window)
        #expect(fixture.probe.restored.isEmpty, "Closing the former owner must not activate the external app")
        let enter = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true))
        #expect(!fixture.input.handle(.keyDown, event: enter, dragging: false))
        if dismiss { fixture.overlay.clearRecovery.dismissRecovery() }
        else {
            let button = try #require(fixture.overlay.clearRecovery.window.firstResponder as? NSButton)
            button.performClick(nil)
            #expect(fixture.overlay.canRedo, "Undo must reach production Ink history")
        }
        fixture.expectOriginalRestoredOnce()
        fixture.overlay.radial.closeImmediately(); fixture.overlay.clearRecovery.dismissRecovery()
        fixture.expectOriginalRestoredOnce()
    }
    @Test(arguments: [false, true])
    func focusedRecoveryInvalidationBeforeQueuedCloseRestoresOriginal(persistent: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(persistent); try fixture.focusRecovery(persistent)
        try fixture.flags([])
        fixture.overlay.verificationDocumentEdit()
        #expect(!fixture.overlay.clearRecovery.state.valid)
        fixture.expectOriginalRestoredOnce()
        await drain(); fixture.overlay.radial.closeImmediately()
        fixture.expectOriginalRestoredOnce()
    }
    @Test(arguments: [false, true], [false, true])
    func captureConsumesTransferredContextOnce(persistent: Bool, editDuringCapture: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(persistent); try fixture.focusRecovery(persistent)
        fixture.overlay.beginCaptureExclusion()
        fixture.expectOriginalRestoredOnce()
        #expect(!fixture.overlay.clearRecovery.window.isVisible && fixture.overlay.radial.session == nil)
        if editDuringCapture { fixture.overlay.verificationDocumentEdit() }
        fixture.overlay.finishCaptureExclusion()
        #expect(fixture.overlay.clearRecovery.state.visible == !editDuringCapture)
        fixture.overlay.clearRecovery.dismissRecovery(); await drain()
        fixture.expectOriginalRestoredOnce()
    }
    @Test(arguments: [false, true])
    func staleRecoveryUndoFinishesOwnershipWithoutEditing(persistent: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(persistent); try fixture.focusRecovery(persistent)
        let expiredRevision = UUID()
        fixture.overlay.clearRecovery.currentRevision = { expiredRevision }
        fixture.overlay.clearRecovery.restoreDrawing()
        #expect(!fixture.overlay.clearRecovery.state.valid && !fixture.overlay.canRedo)
        fixture.expectOriginalRestoredOnce()
        try fixture.flags([]); await drain(); fixture.overlay.radial.closeImmediately()
        fixture.expectOriginalRestoredOnce()
    }
    @Test func realPanelResponderChainUsesOverlayAnnotationHistory() async throws {
        let fixture = try Fixture(); defer { fixture.close() }
        try await fixture.open(true)
        let panel = fixture.overlay.radial.window
        #expect(panel.nextResponder === fixture.overlay.radial.annotationUndo)
        let first = try #require(panel.firstResponder)
        #expect(first.tryToPerform(#selector(AnnotationUndoResponder.undo(_:)), with: nil))
        #expect(fixture.overlay.canRedo)
        #expect(first.tryToPerform(#selector(AnnotationUndoResponder.redo(_:)), with: nil))
        #expect(!fixture.overlay.canRedo)
        let key = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: panel.windowNumber, context: nil, characters: "z", charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6))
        #expect(panel.performKeyEquivalent(with: key))
        #expect(fixture.overlay.canRedo)
    }
}
