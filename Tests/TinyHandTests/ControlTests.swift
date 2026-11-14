import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct ControlTests {
    private func request(_ bridge: ControlBridge, _ value: [String: Any]) throws -> [String: Any] {
        let reply = bridge.handle(try JSONSerialization.data(withJSONObject: value))
        return try #require(JSONSerialization.jsonObject(with: reply) as? [String: Any])
    }
    private func bridge() -> ControlBridge {
        _ = NSApplication.shared
        return ControlBridge(overlay: OverlayController(), accessibility: { false }, openSettings: { _ in }, openHandCreator: {})
    }

    @Test func malformedAndUnknownRequestsAreRejected() throws {
        let api = bridge()
        for data in [Data("[]".utf8), Data("bad json".utf8), Data("{\"version\":true,\"operation\":\"status\"}".utf8)] {
            let result = try #require(JSONSerialization.jsonObject(with: api.handle(data)) as? [String: Any])
            #expect(result["ok"] as? Bool == false)
        }
        for value: [String: Any] in [
            ["version": 2, "operation": "status"], ["version": 1, "operation": "unknown"],
            ["version": 1, "operation": "clear", "extra": true], ["version": 1, "operation": "mode", "mode": "mouse"],
            ["version": 1, "operation": "settings", "section": "does-not-exist"]
        ] { #expect(try request(api, value)["ok"] as? Bool == false) }
    }

    @Test func presentationConfigurationRejectsInvalidBatchesWithoutPartialWrites() throws {
        let api = bridge()
        Preferences.strokeWidth = 7
        for field: [String: Any] in [["magnifierZoom": 0], ["magnifierDiameter": 900], ["trailDelay": -1],
                                     ["trailSpeed": 5000], ["tapSwing": -1], ["inkFadeStyle": "unknown"]] {
            let patch = field.merging(["lineWidth": 18]) { _, b in b }
            #expect(try request(api, ["version": 1, "operation": "configure", "settings": patch])["ok"] as? Bool == false)
            #expect(Preferences.strokeWidth == 7)
        }
    }

    @Test func magnificationPermissionFailureDoesNotActivateAndCaptureReportsItsOwnReason() throws {
        _ = NSApplication.shared
        Preferences.pointerMode = .point
        let overlay = OverlayController(accessibility: { false }, screenRecording: { false }, requestRecording: {})
        defer { overlay.deactivate() }
        let api = ControlBridge(overlay: overlay, accessibility: { false }, openSettings: { _ in }, openHandCreator: {})
        let denied = try request(api, ["version": 1, "operation": "magnifier", "enabled": true])
        #expect((denied["error"] as? [String: Any])?["code"] as? String == "screen-recording")
        #expect(!overlay.isActive && !overlay.isMagnifying)
        overlay.captureScreenshot()
        #expect(overlay.isCapturing)
        let busy = try request(api, ["version": 1, "operation": "magnifier", "enabled": true])
        #expect((busy["error"] as? [String: Any])?["code"] as? String == "unavailable")
        #expect(try request(api, ["version": 1, "operation": "magnifier", "enabled": 1])["ok"] as? Bool == false)
    }

    @Test func invalidGesturesAndNonHandTargetsNeverActivateThePointer() throws {
        _ = NSApplication.shared
        Preferences.pointerMode = .point
        let overlay = OverlayController()
        let api = ControlBridge(overlay: overlay, openSettings: { _ in }, openHandCreator: {})
        _ = overlay.pick(.laser)
        for slot: Any in ["unknown", 1, NSNull(), "first"] {
            #expect(try request(api, ["version": 1, "operation": "gesture", "slot": slot])["ok"] as? Bool == false)
            #expect(!overlay.isActive)
        }
    }

    @Test func newSettingsAreAcknowledgedInOneBatch() throws {
        let api = bridge()
        var notifications = 0
        let observer = NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { _ in notifications += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        let result = try request(api, ["version": 1, "operation": "configure", "settings": ["lineWidth": 12, "opacity": 0.45, "smoothing": 3, "motion": "responsive", "theme": "dark", "showToolbar": false]])
        #expect(result["ok"] as? Bool == true)
        let state = try #require(result["state"] as? [String: Any])
        let settings = try #require(state["settings"] as? [String: Any])
        #expect(settings["lineWidth"] as? Double == 12)
        #expect(settings["opacity"] as? Double == 0.45)
        #expect(settings["motion"] as? String == "responsive")
        #expect(settings["theme"] as? String == "dark")
        #expect(notifications == 1)
    }

    @Test func invalidBatchDoesNotPartiallyApply() throws {
        let api = bridge()
        Preferences.strokeWidth = 7
        Preferences.pointerMotion = .original
        let badPatches: [[String: Any]] = [
            ["lineWidth": 18, "opacity": 2], ["lineWidth": true], ["smoothing": 2.5],
            ["motion": "unknown"], ["theme": "blue"], ["showToolbar": 1], ["size": 0.03], ["lineWidth": -1]
        ]
        for patch in badPatches {
            let response = try request(api, ["version": 1, "operation": "configure", "settings": patch])
            #expect(response["ok"] as? Bool == false)
            #expect(Preferences.strokeWidth == 7)
            #expect(Preferences.pointerMotion == .original)
        }
    }

    @Test func pointModeDoesNotRequireDrawingPermission() throws {
        let api = bridge()
        let point = try request(api, ["version": 1, "operation": "mode", "mode": "point"])
        #expect(point["ok"] as? Bool == true)
        let draw = try request(api, ["version": 1, "operation": "mode", "mode": "draw"])
        #expect(draw["ok"] as? Bool == false)
        #expect(Preferences.pointerMode == .point)
        #expect(try request(api, ["version": 1, "operation": "tool", "tool": "arrow"])["ok"] as? Bool == false)
    }

    @Test func interactUsesStrictBooleansAndKeepsPermissionFallback() throws {
        let api = bridge()
        let response = try request(api, ["version": 1, "operation": "interact", "enabled": true])
        #expect(response["ok"] as? Bool == true)
        #expect((response["state"] as? [String: Any])?["interact"] as? Bool == true)
        #expect(try request(api, ["version": 1, "operation": "interact", "enabled": false])["ok"] as? Bool == false)
        #expect(Preferences.pointerMode.isInteractive)
        for invalid: Any in [1, "true", NSNull()] {
            #expect(try request(api, ["version": 1, "operation": "interact", "enabled": invalid])["ok"] as? Bool == false)
        }
        let configured = try request(api, ["version": 1, "operation": "configure", "settings": ["interactKeepsHand": false]])
        #expect(configured["ok"] as? Bool == true)
        #expect(!Preferences.interactKeepsHand)
        #expect(try request(api, ["version": 1, "operation": "configure", "settings": ["interactKeepsHand": 0]])["ok"] as? Bool == false)
    }

    @Test func keepAtLeastOnePinnedPointerAndRespectLimit() throws {
        let api = bridge()
        Preferences.pinnedStyles = [.laser]
        #expect(try request(api, ["version": 1, "operation": "pin", "style": "laser", "pinned": false])["ok"] as? Bool == false)
        Preferences.pinnedStyles = Array(PointerStyle.allCases.prefix(Preferences.maxPinned))
        let extra = try #require(PointerStyle.allCases.first(where: { !Preferences.pinnedStyles.contains($0) }))
        #expect(try request(api, ["version": 1, "operation": "pin", "style": extra.rawValue, "pinned": true])["ok"] as? Bool == false)
    }

    @Test func screenshotEncodingAndCollisionFreeSaves() throws {
        let context = try #require(CGContext(data: nil, width: 32, height: 24, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(NSColor.systemBlue.cgColor); context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
        let data = try ScreenCapture.png(try #require(context.makeImage()))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("tinyhand-capture-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try ScreenCapture.save(data, in: directory)
        let second = try ScreenCapture.save(data, in: directory)
        #expect(first != second)
        #expect(try Data(contentsOf: first) == data)
        let decoded = try #require(NSBitmapImageRep(data: data))
        #expect(decoded.pixelsWide == 32 && decoded.pixelsHigh == 24)
        let clipboard = NSPasteboard.withUniqueName()
        defer { clipboard.releaseGlobally() }
        #expect(ScreenCapture.copy(data, to: clipboard))
        #expect(clipboard.data(forType: .png) == data)
    }

    @Test func toolCycleOrderAndStrictPermissionRejection() throws {
        #expect(DrawingTool.allCases.map(\.rawValue) == ["pen", "rectangle", "arrow", "text", "number"])
        #expect(DrawingTool.allCases.map(\.next) == [.rectangle, .arrow, .text, .number, .pen])
        let api = bridge()
        Preferences.drawingTool = .text
        for mode in PointerMode.allCases {
            Preferences.pointerMode = mode
            for fields: [String: Any] in [["operation": "cycle-tool"], ["operation": "tool", "tool": "pen"]] {
                let reply = try request(api, fields.merging(["version": 1]) { old, _ in old })
                #expect(reply["ok"] as? Bool == false)
                #expect((reply["error"] as? [String: Any])?["code"] as? String == "accessibility")
                #expect(Preferences.drawingTool == .text && Preferences.pointerMode == mode)
                #expect((reply["state"] as? [String: Any])?["active"] as? Bool == false)
            }
        }
        for fields: [String: Any] in [
            ["operation": "cycle-tool", "tool": "pen"], ["operation": "cycle-tool", "activate": true],
            ["operation": "tool", "tool": "cycle"], ["operation": "tool", "tool": NSNull()], ["operation": "tool", "tool": 1]
        ] {
            let reply = try request(api, fields.merging(["version": 1]) { old, _ in old })
            #expect((reply["error"] as? [String: Any])?["code"] as? String == "invalid-request")
            #expect(Preferences.drawingTool == .text)
        }
    }

    @Test func captureRejectsToolChangesWithActualReasonBeforePermission() throws {
        _ = NSApplication.shared
        Preferences.pointerMode = .point
        Preferences.drawingTool = .number
        let overlay = OverlayController(accessibility: { false })
        let api = ControlBridge(overlay: overlay, accessibility: { false }, openSettings: { _ in }, openHandCreator: {})
        // Capture sets its busy state synchronously; cancel before the async task
        // can capture anything or touch clipboard/files.
        overlay.captureScreenshot()
        defer { overlay.deactivate() }
        #expect(overlay.isCapturing)
        let active = overlay.isActive
        for fields: [String: Any] in [["operation": "cycle-tool"], ["operation": "tool", "tool": "pen"]] {
            let reply = try request(api, fields.merging(["version": 1]) { old, _ in old })
            #expect((reply["error"] as? [String: Any])?["code"] as? String == "capturing")
            #expect(Preferences.drawingTool == .number && Preferences.pointerMode == .point && overlay.isActive == active)
        }
    }
}
