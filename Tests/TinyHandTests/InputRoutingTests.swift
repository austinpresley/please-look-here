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
    @Test func drawRouteSurvivesDeactivationUntilRelease() throws {
        let tap = InputTap()
        tap.hardwareFlags = { [] }
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

    @Test func differentButtonsKeepIndependentRoutes() throws {
        let tap = InputTap()
        tap.hardwareFlags = { [] }
        tap.interactKey = .maskAlternate
        tap.setActive(true)
        let left = try event(.leftMouseDown)
        let right = try event(.rightMouseDown, button: 1, flags: [.maskAlternate, .maskShift])
        #expect(tap.handle(type: .leftMouseDown, event: left) == nil)
        #expect(tap.handle(type: .rightMouseDown, event: right) != nil)
        #expect(!right.flags.contains(.maskAlternate))
        #expect(right.flags.contains(.maskShift))
        tap.interactKey = .maskCommand
        let rightUp = try event(.rightMouseUp, button: 1, flags: [.maskAlternate, .maskShift])
        #expect(tap.handle(type: .rightMouseUp, event: rightUp) != nil)
        #expect(!rightUp.flags.contains(.maskAlternate))
        #expect(rightUp.flags.contains(.maskShift))
        let leftUp = try event(.leftMouseUp)
        #expect(tap.handle(type: .leftMouseUp, event: leftUp) == nil)
    }

    @Test func toolbarPressRemainsNativeOutsideItsBounds() throws {
        let tap = InputTap()
        tap.hardwareFlags = { [] }
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
        tap.hardwareFlags = { [] }
        tap.setActive(true)
        _ = tap.handle(type: .leftMouseDown, event: try event(.leftMouseDown))
        let drag = try event(.leftMouseDragged)
        #expect(tap.handle(type: .leftMouseDragged, event: drag) != nil)
        #expect(drag.type == .mouseMoved)
        _ = tap.handle(type: .leftMouseUp, event: try event(.leftMouseUp))
    }

    @Test func staleCallbacksCannotRecreateAReleasedGesture() async throws {
        let tap = InputTap()
        tap.hardwareFlags = { [] }
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
