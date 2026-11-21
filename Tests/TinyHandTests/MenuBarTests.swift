import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct MenuBarTests {
    private func event(_ type: CGEventType, button: Int64 = 0, key: Int64 = 53, at point: CGPoint = CGPoint(x: 500, y: 500)) -> CGEvent {
        let event = CGEvent(source: nil)!
        event.type = type; event.location = point
        event.setIntegerValueField(.mouseEventButtonNumber, value: button)
        event.setIntegerValueField(.keyboardEventKeycode, value: key)
        return event
    }
    @Test(arguments: [Int64(0), 1, 2]) func outsideDismissOwnsWholePairAcrossClosure(_ button: Int64) {
        let router = ControlInput()
        let down: CGEventType = button == 0 ? .leftMouseDown : button == 1 ? .rightMouseDown : .otherMouseDown
        let drag: CGEventType = button == 0 ? .leftMouseDragged : button == 1 ? .rightMouseDragged : .otherMouseDragged
        let up: CGEventType = button == 0 ? .leftMouseUp : button == 1 ? .rightMouseUp : .otherMouseUp
        router.configure(open: true, nativeMenu: false, regions: [CGRect(x: 0, y: 0, width: 320, height: 320)])
        let result = router.handle(down, event: event(down, button: button))
        #expect(result.consume && result.dismiss)
        router.configure(open: false, nativeMenu: false, regions: [])
        #expect(router.needsTap)
        #expect(router.handle(down, event: event(down, button: button)).consume)
        #expect(router.handle(drag, event: event(drag, button: button)).consume)
        #expect(router.handle(up, event: event(up, button: button)).consume)
        #expect(!router.needsTap)
        #expect(!router.handle(up, event: event(up, button: button)).consume)
    }
    @Test func escapeRepeatsAndOverlappingButtonsDrainIndependently() {
        let router = ControlInput()
        router.configure(open: true, nativeMenu: false, regions: [])
        #expect(router.handle(.leftMouseDown, event: event(.leftMouseDown)).dismiss)
        #expect(router.handle(.rightMouseDown, event: event(.rightMouseDown, button: 1)).dismiss)
        #expect(router.handle(.keyDown, event: event(.keyDown)).dismiss)
        router.configure(open: false, nativeMenu: false, regions: [])
        for _ in 0..<3 { #expect(router.handle(.keyDown, event: event(.keyDown)).consume) }
        #expect(router.handle(.leftMouseUp, event: event(.leftMouseUp)).consume)
        #expect(router.handle(.rightMouseUp, event: event(.rightMouseUp, button: 1)).consume)
        #expect(router.needsTap)
        #expect(router.handle(.keyUp, event: event(.keyUp)).consume)
        #expect(!router.needsTap)
    }
    @Test func nativeControlsMenusAndExistingReleasesKeepTheirRouting() {
        let router = ControlInput()
        router.configure(open: true, nativeMenu: false, regions: [CGRect(x: 0, y: 0, width: 20, height: 20), CGRect(x: 400, y: 400, width: 320, height: 320)])
        for type: CGEventType in [.leftMouseDown, .leftMouseUp, .keyUp, .flagsChanged, .mouseMoved] {
            #expect(!router.handle(type, event: event(type)).consume)
        }
        #expect(!router.handle(.keyDown, event: event(.keyDown, key: 8)).consume)
        router.configure(open: true, nativeMenu: true, regions: [])
        #expect(!router.handle(.keyDown, event: event(.keyDown)).consume)
        #expect(!router.handle(.leftMouseDown, event: event(.leftMouseDown)).consume)
        router.configure(open: false, nativeMenu: false, regions: [])
        #expect(!router.needsTap)
    }
    @Test func openingControlsCannotStealAnAlreadyClaimedRadialEscapePair() {
        let tap = InputTap()
        tap.configureRadial(trigger: .option, eligible: true)
        let flags = event(.flagsChanged, key: 58); flags.flags = .maskAlternate
        _ = tap.handle(type: .flagsChanged, event: flags)
        tap.radial.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(tap.handle(type: .keyDown, event: event(.keyDown)) == nil)
        tap.configureRadial(trigger: nil, eligible: false)
        tap.configureControls(open: true, nativeMenu: false, regions: [])
        let repeated = event(.keyDown); repeated.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        #expect(tap.handle(type: .keyDown, event: repeated) == nil)
        #expect(tap.handle(type: .keyUp, event: event(.keyUp)) == nil)
        let radial = tap.diagnostics["radial"] as? [String: Any]
        let controls = tap.diagnostics["controls"] as? [String: Any]
        #expect((radial?["keys"] as? [Int64])?.isEmpty == true)
        #expect((controls?["keys"] as? [Int64])?.isEmpty == true)
        tap.configureControls(open: false, nativeMenu: false, regions: [])
    }
    @Test(arguments: [Int64(0), 1, 2]) func controlsCannotStealAlreadyClaimedRadialMousePairs(_ button: Int64) {
        let tap = InputTap(); tap.configureRadial(trigger: .option, eligible: true)
        let flags = event(.flagsChanged, key: 58); flags.flags = .maskAlternate
        _ = tap.handle(type: .flagsChanged, event: flags)
        tap.radial.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        let down: CGEventType = button == 0 ? .leftMouseDown : button == 1 ? .rightMouseDown : .otherMouseDown
        let up: CGEventType = button == 0 ? .leftMouseUp : button == 1 ? .rightMouseUp : .otherMouseUp
        #expect(tap.handle(type: down, event: event(down, button: button)) == nil)
        tap.configureRadial(trigger: nil, eligible: false)
        tap.configureControls(open: true, nativeMenu: false, regions: [])
        #expect(tap.handle(type: down, event: event(down, button: button)) == nil)
        #expect(tap.handle(type: up, event: event(up, button: button)) == nil)
        #expect(((tap.diagnostics["radial"] as? [String: Any])?["buttons"] as? [Int64])?.isEmpty == true)
        #expect(((tap.diagnostics["controls"] as? [String: Any])?["buttons"] as? [Int64])?.isEmpty == true)
        tap.configureControls(open: false, nativeMenu: false, regions: [])
    }
    @Test func openingControlsCannotStealAnAlreadyCapturedDrawingMousePair() {
        let tap = InputTap(); tap.setActive(true)
        #expect(tap.handle(type: .leftMouseDown, event: event(.leftMouseDown)) == nil)
        tap.setActive(false)
        tap.configureControls(open: true, nativeMenu: false, regions: [])
        #expect(tap.handle(type: .leftMouseDown, event: event(.leftMouseDown)) == nil)
        #expect(tap.handle(type: .leftMouseUp, event: event(.leftMouseUp)) == nil)
        #expect((tap.diagnostics["capturedButtons"] as? [Int64])?.isEmpty == true)
        #expect(((tap.diagnostics["controls"] as? [String: Any])?["buttons"] as? [Int64])?.isEmpty == true)
        tap.configureControls(open: false, nativeMenu: false, regions: [])
    }
    @Test func nativeMenuOutsideClickDoesNotReplayToPresentation() {
        let router = ControlInput()
        router.configure(open: true, nativeMenu: true, regions: [CGRect(x: 0, y: 0, width: 20, height: 20)])
        let menu = CGRect(x: 400, y: 400, width: 320, height: 320)
        #expect(!router.handle(.leftMouseDown, event: event(.leftMouseDown), menuRegions: [menu]).consume)
        let outside = router.handle(.leftMouseDown, event: event(.leftMouseDown, at: CGPoint(x: 900, y: 900)), menuRegions: [menu])
        #expect(outside.consume && outside.dismiss)
        router.configure(open: false, nativeMenu: false, regions: [])
        #expect(router.handle(.leftMouseUp, event: event(.leftMouseUp)).consume)
        #expect(!router.needsTap)
    }
    @Test func statusClickOwnsBothHalvesAndCommitsOnlyOnRelease() {
        let router = ControlInput()
        let region = CGRect(x: 400, y: 400, width: 320, height: 320)
        router.configure(open: true, nativeMenu: false, regions: [region])
        let down = router.handle(.leftMouseDown, event: event(.leftMouseDown))
        #expect(down.consume && !down.dismiss && down.statusClick == nil)
        #expect(router.handle(.leftMouseDown, event: event(.leftMouseDown)).statusClick == nil)
        let up = router.handle(.leftMouseUp, event: event(.leftMouseUp))
        #expect(up.consume && up.statusClick == false)
        #expect(router.handle(.rightMouseDown, event: event(.rightMouseDown, button: 1)).consume)
        #expect(router.handle(.rightMouseUp, event: event(.rightMouseUp, button: 1)).statusClick == true)
        #expect(router.handle(.leftMouseDown, event: event(.leftMouseDown)).consume)
        router.configure(open: false, nativeMenu: false, regions: [])
        let canceled = router.handle(.leftMouseUp, event: event(.leftMouseUp))
        #expect(canceled.consume && canceled.statusClick == nil)
    }
    @Test func controlOwnershipRunsBeforeDrawingAndSurvivesTapShutdown() {
        let tap = InputTap()
        tap.setActive(true)
        tap.configureControls(open: true, nativeMenu: false, regions: [CGRect(x: 0, y: 0, width: 320, height: 320)])
        #expect(tap.handle(type: .leftMouseDown, event: event(.leftMouseDown)) == nil)
        #expect((tap.diagnostics["capturedButtons"] as? [Int64])?.isEmpty == true)
        tap.configureControls(open: false, nativeMenu: false, regions: [])
        tap.setActive(false)
        #expect(tap.handle(type: .leftMouseDragged, event: event(.leftMouseDragged)) == nil)
        #expect(tap.handle(type: .leftMouseUp, event: event(.leftMouseUp)) == nil)
        #expect(tap.handle(type: .leftMouseUp, event: event(.leftMouseUp)) != nil)
        tap.configureControls(open: true, nativeMenu: false, regions: [])
        #expect(tap.handle(type: .keyDown, event: event(.keyDown)) == nil)
        tap.configureControls(open: false, nativeMenu: false, regions: [])
        #expect(tap.handle(type: .keyDown, event: event(.keyDown)) == nil)
        #expect(tap.handle(type: .keyUp, event: event(.keyUp)) == nil)
        #expect(tap.handle(type: .keyDown, event: event(.keyDown, key: 8)) != nil)
    }
    @Test func shortcutConflictNamesCommandAndOpensShortcutsWithoutChangingAssignments() throws {
        _ = NSApplication.shared
        let overlay = OverlayController()
        let commands = MenuBarCommands(overlay: overlay)
        let shortcut = Shortcut(keyCode: 8, modifiers: 4096, display: "⌃C")
        Preferences.setShortcut(shortcut, for: .capture)
        var request: [String: Any] = [:]
        commands.perform = { request = $0 }
        commands.shortcutConflicts = ["capture": "⌃C is unavailable. Choose another shortcut."]
        let route = try #require(commands.menu.items.first { $0.title == "Review Shortcut Conflict…" })
        #expect(!route.isHidden && route.isEnabled)
        #expect(route.toolTip?.contains("Take Screenshot: ⌃C") == true)
        NSApp.sendAction(try #require(route.action), to: route.target, from: route)
        #expect(request["operation"] as? String == "settings")
        #expect(request["section"] as? String == "shortcuts")
        #expect(Preferences.shortcut(for: .capture) == shortcut)
        commands.shortcutConflicts = [:]
        #expect(route.isHidden)
        Preferences.setShortcut(nil, for: .capture)
    }
    @Test func nativeSecondaryCommandsObserveActualStateAndSavedShortcuts() throws {
        _ = NSApplication.shared
        Preferences.resetAll()
        defer { Preferences.resetAll() }
        let overlay = OverlayController(accessibility: { false })
        let commands = MenuBarCommands(overlay: overlay)
        let bridge = ControlBridge(overlay: overlay, accessibility: { false }, openSettings: { _ in }, openHandCreator: {})
        var response: [String: Any] = [:]
        commands.perform = { request in response = (try? JSONSerialization.jsonObject(with: bridge.handle(JSONSerialization.data(withJSONObject: request))) as? [String: Any]) ?? [:] }
        let pointer = try #require(commands.menu.items.first { $0.title == "Pointer" }?.submenu)
        let drawing = try #require(commands.menu.items.first { $0.title == "Drawing" }?.submenu)
        let interact = try #require(pointer.items.first { $0.title == "Cursor" })
        let arrow = try #require(drawing.items.first { $0.title == "Arrow" })
        #expect(interact.state == .on && interact.isEnabled)
        for _ in 0..<2 {
            NSApp.sendAction(try #require(interact.action), to: interact.target, from: interact)
            #expect(response["ok"] as? Bool == true && overlay.mode == .point)
        }
        #expect(pointer.items.contains { $0.title == "Cursor ↔ last tool" })
        #expect(!arrow.isEnabled)
        #expect(!drawing.items.first(where: { $0.title == "Undo Annotation" })!.isEnabled)
        // Invoke the real menu target despite disabled UI to prove validation is
        // still authoritative for stale/AX requests.
        NSApp.sendAction(try #require(arrow.action), to: arrow.target, from: arrow)
        #expect(response["ok"] as? Bool == false)
        #expect(Preferences.pointerMode == .point)
        let chooser = try #require(pointer.items.first { $0.title == "Choose Pointer" }?.submenu)
        #expect(chooser.items.map(\.title) == PointerCatalog.selectableStyles.map(\.title))
        #expect(chooser.items.allSatisfy { $0.keyEquivalent.isEmpty })
        Preferences.setShortcut(Shortcut(keyCode: 8, modifiers: 4096, display: "⌃C"), for: .capture)
        commands.refresh()
        let presentation = try #require(commands.menu.items.first { $0.title == "Presentation" }?.submenu)
        #expect(presentation.items.first?.keyEquivalent == "c")
        #expect(commands.menu.items.last?.keyEquivalent == "q")
        #expect(!overlay.isActive)
    }
}
