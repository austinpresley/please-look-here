import AppKit
import ApplicationServices

// Read only app-owned windows, or move within the guarded disposable canvas.
func emit(_ value: Any) {
    print(String(decoding: try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self))
}
let arguments = Array(CommandLine.arguments.dropFirst())
guard ProcessInfo.processInfo.environment["TINYHAND_TEST_MODE"] == "1" else { exit(2) }
if arguments.count == 2, arguments[0] == "windows", let pid = Int32(arguments[1]),
   NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.austinpresley.pleaselookhere.integration" {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    emit(windows.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid })
} else if arguments.count == 3, arguments[0] == "move", let x = Double(arguments[1]), let y = Double(arguments[2]), x.isFinite, y.isFinite {
    let point = CGPoint(x: x, y: y)
    guard AXIsProcessTrusted(),
          let fixture = NSRunningApplication.runningApplications(withBundleIdentifier: "com.austinpresley.tinyhand.fixture").first,
          NSWorkspace.shared.frontmostApplication?.processIdentifier == fixture.processIdentifier,
          let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
          windows.contains(where: { window in
              guard (window[kCGWindowOwnerPID as String] as? Int32) == fixture.processIdentifier,
                    window[kCGWindowName as String] as? String == "TinyHand test canvas",
                    let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                    let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
              return rect.contains(point)
          }) else { emit(["ok": false, "error": "Frontmost public fixture and in-window coordinates required; no input posted"]); exit(2) }
    CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: .mouseMoved,
            mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(80_000)
    emit(["ok": true, "point": [x, y], "frontmostPID": fixture.processIdentifier])
} else { exit(2) }
