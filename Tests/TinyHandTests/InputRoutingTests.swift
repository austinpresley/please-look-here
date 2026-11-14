import AppKit
import Testing
@testable import TinyHand

private func event(_ type: CGEventType, button: Int64 = 0, point: CGPoint = CGPoint(x: 100, y: 100), flags: CGEventFlags = []) throws -> CGEvent {
    let value = try #require(CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button == 0 ? .left : button == 1 ? .right : .center))
    value.setIntegerValueField(.mouseEventButtonNumber, value: button)
    value.flags = flags
    return value
}

@Suite(.serialized) @MainActor struct InputRoutingTests {
    @Test func lockFallbackForwardsNewUnlockInputAndDrainsUnrelatedDrawingRelease() throws {
        var locked = false
        let tap = InputTap(sessionLocked: { locked })
        tap.setActive(true)
        #expect(tap.handle(type: .leftMouseDown, event: try event(.leftMouseDown)) == nil)
        locked = true
        let unlock = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true))
        #expect(tap.handle(type: .keyDown, event: unlock) != nil)
        #expect(tap.handle(type: .leftMouseUp, event: try event(.leftMouseUp)) == nil)
        let keyUp = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: false))
        #expect(tap.handle(type: .keyUp, event: keyUp) != nil)
    }

    @Test func lockFallbackRetainsUnrelatedControlsKeyOwner() throws {
        var locked = false
        let tap = InputTap(sessionLocked: { locked })
        tap.configureControls(open: true, nativeMenu: false, regions: [])
        let escape = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true))
        #expect(tap.handle(type: .keyDown, event: escape) == nil)
        locked = true
        #expect(tap.handle(type: .rightMouseDown, event: try event(.rightMouseDown, button: 1)) != nil)
        let escapeUp = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false))
        #expect(tap.handle(type: .keyUp, event: escapeUp) == nil)
        #expect(tap.handle(type: .rightMouseUp, event: try event(.rightMouseUp, button: 1)) != nil)
    }
    @Test func lockFallbackKeepsOwnedControlsEscapeRepeatsAndRelease() throws {
        var locked = false
        let tap = InputTap(sessionLocked: { locked })
        tap.configureControls(open: true, nativeMenu: false, regions: [])
        let down = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true))
        #expect(tap.handle(type: .keyDown, event: down) == nil)
        locked = true
        for _ in 0..<3 {
            let repeatDown = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true))
            repeatDown.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
            #expect(tap.handle(type: .keyDown, event: repeatDown) == nil)
        }
        let up = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false))
        #expect(tap.handle(type: .keyUp, event: up) == nil)
    }

    @Test func lockFallbackKeepsOwnedRadialEscapeRepeatsAndRelease() throws {
        var locked = false
        let tap = InputTap(sessionLocked: { locked })
        tap.configureRadial(trigger: .option, eligible: true)
        let flag = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 58, keyDown: true))
        flag.type = .flagsChanged; flag.flags = .maskAlternate
        #expect(tap.handle(type: .flagsChanged, event: flag) != nil)
        let down = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true))
        #expect(tap.handle(type: .keyDown, event: down) == nil)
        locked = true
        let repeatDown = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true))
        repeatDown.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        #expect(tap.handle(type: .keyDown, event: repeatDown) == nil)
        let up = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false))
        #expect(tap.handle(type: .keyUp, event: up) == nil)
    }

    @Test func drawRouteSurvivesDeactivationUntilRelease() throws {
        let tap = InputTap()
        tap.setActive(true)
        let down = try event(.leftMouseDown)
        #expect(tap.handle(type: .leftMouseDown, event: down) == nil)
        tap.setActive(false)
        let unrelated = try event(.rightMouseDown, button: 1)
        #expect(tap.handle(type: .rightMouseDown, event: unrelated) != nil)
        let up = try event(.leftMouseUp)
        #expect(tap.handle(type: .leftMouseUp, event: up) == nil)
        let newDown = try event(.leftMouseDown)
        #expect(tap.handle(type: .leftMouseDown, event: newDown) != nil)
    }

    @Test func modifiersNeverTemporarilyEnableInteraction() throws {
        // A legacy stored key must have no effect on event routing.
        Preferences.storage.set("option", forKey: "interactKey")
        defer { Preferences.storage.removeObject(forKey: "interactKey") }
        let tap = InputTap()
        tap.setActive(true)
        for flags: CGEventFlags in [.maskAlternate, .maskCommand, .maskControl, [.maskAlternate, .maskShift]] {
            let down = try event(.leftMouseDown, flags: flags)
            #expect(tap.handle(type: .leftMouseDown, event: down) == nil)
            #expect(down.flags == flags)
            let up = try event(.leftMouseUp, flags: flags)
            #expect(tap.handle(type: .leftMouseUp, event: up) == nil)
            #expect(up.flags == flags)
        }
    }

    @Test func interactiveInputPreservesModifiersAndNativeDragAcrossModeChange() throws {
        let tap = InputTap()
        let flags: CGEventFlags = [.maskAlternate, .maskCommand, .maskShift]
        let down = try event(.leftMouseDown, flags: flags)
        #expect(tap.handle(type: .leftMouseDown, event: down) != nil)
        #expect(down.flags == flags)
        tap.setActive(true)
        let drag = try event(.leftMouseDragged, flags: flags)
        #expect(tap.handle(type: .leftMouseDragged, event: drag) != nil)
        #expect(drag.type == .leftMouseDragged && drag.flags == flags)
        let up = try event(.leftMouseUp, flags: flags)
        #expect(tap.handle(type: .leftMouseUp, event: up) != nil)
        #expect(up.flags == flags)
        let next = try event(.leftMouseDown)
        #expect(tap.handle(type: .leftMouseDown, event: next) == nil)
        #expect(tap.handle(type: .leftMouseUp, event: try event(.leftMouseUp)) == nil)
    }

    @Test func differentButtonsKeepIndependentRoutes() throws {
        let tap = InputTap()
        tap.setActive(true)
        #expect(tap.handle(type: .leftMouseDown, event: try event(.leftMouseDown)) == nil)
        tap.setActive(false)
        #expect(tap.handle(type: .rightMouseDown, event: try event(.rightMouseDown, button: 1)) != nil)
        #expect(tap.handle(type: .leftMouseUp, event: try event(.leftMouseUp)) == nil)
        #expect(tap.handle(type: .rightMouseUp, event: try event(.rightMouseUp, button: 1)) != nil)
    }

    @Test func toolbarPressRemainsNativeOutsideItsBounds() throws {
        let tap = InputTap()
        tap.setActive(true)
        tap.passThroughRects = [CGRect(x: 0, y: 0, width: 50, height: 50)]
        let down = try event(.leftMouseDown, point: CGPoint(x: 20, y: 20))
        #expect(tap.handle(type: .leftMouseDown, event: down) != nil)
        let drag = try event(.leftMouseDragged, point: CGPoint(x: 200, y: 200))
        #expect(tap.handle(type: .leftMouseDragged, event: drag) != nil)
        #expect(drag.type == .leftMouseDragged)
        let up = try event(.leftMouseUp, point: CGPoint(x: 200, y: 200))
        #expect(tap.handle(type: .leftMouseUp, event: up) != nil)
    }

    @Test func capturedDragBecomesMovementWithoutNativeDragging() throws {
        let tap = InputTap()
        tap.setActive(true)
        _ = tap.handle(type: .leftMouseDown, event: try event(.leftMouseDown))
        let drag = try event(.leftMouseDragged)
        #expect(tap.handle(type: .leftMouseDragged, event: drag) != nil)
        #expect(drag.type == .mouseMoved)
        _ = tap.handle(type: .leftMouseUp, event: try event(.leftMouseUp))
    }

    @Test func staleCallbacksCannotRecreateAReleasedGesture() async throws {
        let tap = InputTap()
        var downs = 0, ups = 0
        tap.onMouseDown = { _, _, _, _ in downs += 1 }
        tap.onMouseUp = { _, _ in ups += 1 }
        tap.setActive(true)
        _ = tap.handle(type: .leftMouseDown, event: try event(.leftMouseDown))
        tap.setActive(false); tap.setActive(true)
        _ = tap.handle(type: .leftMouseUp, event: try event(.leftMouseUp))
        _ = tap.handle(type: .leftMouseDown, event: try event(.leftMouseDown))
        _ = tap.handle(type: .leftMouseUp, event: try event(.leftMouseUp))
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(downs == 1)
        #expect(ups == 1)
    }
}
