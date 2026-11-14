import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct LifecycleTests {
    @Test func everySystemShutdownSignalAndRecoverySignalIsObserved() {
        let workspace = NotificationCenter(), distributed = NotificationCenter(), app = NotificationCenter()
        var stops: [String] = [], recoveries = 0
        var lifecycle: PresentationLifecycle? = PresentationLifecycle(workspace: workspace, distributed: distributed,
            application: app, stop: { stops.append($0) }, recover: { recoveries += 1 })
        for name in ["com.apple.screenIsLocked", "com.apple.screensaver.didstart"] {
            distributed.post(name: Notification.Name(name), object: nil)
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspace.post(name: name, object: nil)
        }
        workspace.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        app.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(stops.count == 5 && recoveries == 2)
        #expect(lifecycle != nil)
        lifecycle = nil
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        #expect(stops.count == 5)
    }

    @Test func systemShutdownRestoresInactiveStateAndDoesNotAutoReactivate() {
        _ = NSApplication.shared
        Preferences.pointerMode = .point
        let overlay = OverlayController()
        var dismissed = 0
        overlay.onDismissControls = { dismissed += 1 }
        #expect(overlay.activate())
        overlay.stopForSystem("test sleep")
        #expect(!overlay.isActive && !overlay.pointerVisible && !overlay.toolbarVisible)
        #expect(overlay.motionClock == "sleeping")
        overlay.recoverPresentation()
        #expect(!overlay.isActive && dismissed == 1)
    }

    @Test func spaceRecoveryPreservesHiddenToolbarAndWindowMembership() {
        _ = NSApplication.shared
        Preferences.pointerMode = .point; Preferences.showToolbar = false
        let overlay = OverlayController()
        defer { overlay.deactivate() }
        #expect(overlay.activate())
        overlay.recoverPresentation()
        #expect(overlay.isActive && !overlay.toolbarVisible)
        for window in overlay.windowsForTesting {
            if window.collectionBehavior.contains(.canJoinAllSpaces) {
                window.rejoinAllSpaces()
                #expect(window.collectionBehavior.contains(.canJoinAllSpaces))
            }
        }
    }

    @Test func lockedSessionInputNeverConsumesAnUnlockPress() throws {
        let tap = InputTap(sessionLocked: { true })
        tap.setActive(true)
        let down = try #require(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
            mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left))
        #expect(tap.handle(type: .leftMouseDown, event: down) != nil)
        #expect(tap.diagnostics["active"] as? Bool == false)
        #expect((tap.diagnostics["capturedButtons"] as? [Int64])?.isEmpty == true)
    }

    @Test func idleSleepWaitsForEveryMotionOwner() {
        #expect(!MotionPacing.shouldSleep(stillFor: 2.99, settling: false, held: false, drawing: false))
        #expect(MotionPacing.shouldSleep(stillFor: 3, settling: false, held: false, drawing: false))
        #expect(!MotionPacing.shouldSleep(stillFor: 30, settling: true, held: false, drawing: false))
        #expect(!MotionPacing.shouldSleep(stillFor: 30, settling: false, held: true, drawing: false))
        #expect(!MotionPacing.shouldSleep(stillFor: 30, settling: false, held: false, drawing: true))
    }

    @Test func nativePressReleasedOverOurOwnUIStopsBlockingGestures() throws {
        _ = NSApplication.shared
        Preferences.pointerMode = .point; Preferences.handSound = false
        let overlay = OverlayController()
        defer { overlay.deactivate() }
        #expect(overlay.activate())
        #expect(overlay.canUseHandGestures)
        let down = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        overlay.observeForVerification(down, own: false)
        #expect(!overlay.canUseHandGestures)
        let up = try #require(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [],
            timestamp: 0.1, windowNumber: 0, context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
        overlay.observeForVerification(up, own: true)
        #expect(overlay.canUseHandGestures)
    }
}
