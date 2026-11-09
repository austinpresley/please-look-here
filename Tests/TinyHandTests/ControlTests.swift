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
}
