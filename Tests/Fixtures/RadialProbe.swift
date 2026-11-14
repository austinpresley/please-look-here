import AppKit
import ApplicationServices

// Test-only native input and compositor readback over the public fixture.
let env = ProcessInfo.processInfo.environment
let args = Array(CommandLine.arguments.dropFirst())
guard env["TINYHAND_TEST_MODE"] == "1", env["TINYHAND_DEFAULTS_SUITE"]?.hasPrefix("com.austinpresley.tinyhand.s013.") == true else { exit(2) }
func emit(_ value: Any) { print(String(decoding: try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self)) }
func windows() -> [[String: Any]] { CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [] }
guard let fixture = NSRunningApplication.runningApplications(withBundleIdentifier: "com.austinpresley.tinyhand.fixture").first,
      let info = windows().first(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == fixture.processIdentifier && $0[kCGWindowName as String] as? String == "TinyHand test canvas" }),
      let b = info[kCGWindowBounds as String] as? NSDictionary, let bounds = CGRect(dictionaryRepresentation: b as CFDictionary) else { exit(3) }
func guardFocus() { if NSWorkspace.shared.frontmostApplication?.processIdentifier != fixture.processIdentifier { fputs("Public fixture is not frontmost; no input posted\n", stderr); exit(4) } }
func readAX(_ element: AXUIElement, _ name: String) -> Any? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}
func walk(_ element: AXUIElement, depth: Int = 0) -> [[String: Any]] {
    guard depth < 9 else { return [] }
    let title = readAX(element, kAXTitleAttribute) as? String ?? ""
    let description = readAX(element, kAXDescriptionAttribute) as? String ?? ""
    var result: [[String: Any]] = [["title": title, "description": description, "role": readAX(element, kAXRoleAttribute) as? String ?? "", "value": String(describing: readAX(element, kAXValueAttribute) ?? ""), "enabled": readAX(element, kAXEnabledAttribute) as? Bool ?? false]]
    if args.first == "press", args.count == 2, title == args[1] || description == args[1] {
        let code = AXUIElementPerformAction(element, kAXPressAction as CFString)
        result[0]["pressResult"] = code.rawValue
    }
    for child in readAX(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] { result += walk(child, depth: depth + 1) }
    return result
}
if args.first == "activate-fixture" {
    emit(["ok": fixture.activate(options: [.activateIgnoringOtherApps])])
} else if args.first == "own-key", args.count == 2 {
    guard let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier == "com.austinpresley.pleaselookhere.integration" else { exit(11) }
    let close = args[1] == "close-settings"
    guard close || args[1] == "cancel-text",
          windows().contains(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == app.processIdentifier && ($0[kCGWindowName as String] as? String) == (close ? "Look Here Please Settings" : "Add Text") }) else { exit(12) }
    let source = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: source, virtualKey: close ? 13 : 53, keyDown: down)
        e?.flags = close ? .maskCommand : []; e?.post(tap: .cghidEventTap); usleep(80_000)
    }
    if close {
        let e = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false)
        e?.type = .flagsChanged; e?.flags = []; e?.post(tap: .cghidEventTap)
    }
    emit(["ok": true])
} else if args.first == "ax" || args.first == "press" {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.austinpresley.pleaselookhere.integration").first else { exit(3) }
    emit(walk(AXUIElementCreateApplication(app.processIdentifier)))
} else if args.first == "state" {
    let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.austinpresley.pleaselookhere.integration").first
    func inputState(_ source: CGEventSourceStateID) -> [String: Any] {
        ["flags": CGEventSource.flagsState(source).rawValue,
         "buttons": (0..<32).filter { CGEventSource.buttonState(source, button: CGMouseButton(rawValue: UInt32($0))!) }]
    }
    let menuWindows = windows().filter { ($0[kCGWindowLayer as String] as? Int) == Int(CGWindowLevelForKey(.popUpMenuWindow)) }.map { info in
        info.filter { [kCGWindowOwnerPID, kCGWindowNumber, kCGWindowBounds, kCGWindowLayer].map { $0 as String }.contains($0.key) }
    }
    var tapCount: UInt32 = 0
    let countResult = CGGetEventTapList(0, nil, &tapCount)
    var taps = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(tapCount))
    let tapResult = CGGetEventTapList(tapCount, &taps, &tapCount)
    let appTaps: [[String: Any]] = taps.prefix(Int(tapCount)).filter { $0.tappingProcess == app?.processIdentifier }.map {
        ["id": $0.eventTapID, "enabled": $0.enabled, "point": $0.tapPoint.rawValue,
         "events": $0.eventsOfInterest, "maxUsecLatency": $0.maxUsecLatency]
    }
    emit(["fixture": info, "appPID": app?.processIdentifier ?? -1, "appWindows": windows().filter { ($0[kCGWindowOwnerPID as String] as? Int32) == app?.processIdentifier }, "menuWindows": menuWindows, "appTaps": appTaps, "tapListResult": [countResult.rawValue, tapResult.rawValue], "bounds": [bounds.minX, bounds.minY, bounds.width, bounds.height], "cursor": [CGEvent(source: nil)?.location.x ?? -1, CGEvent(source: nil)?.location.y ?? -1], "screenCount": NSScreen.screens.count, "frontmost": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "", "combinedInput": inputState(.combinedSessionState), "hidInput": inputState(.hidSystemState)])
} else if args.first == "shot", args.count == 2 {
    guardFocus()
    guard let image = CGWindowListCreateImage(bounds, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution]), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { exit(5) }
    try png.write(to: URL(fileURLWithPath: args[1])); emit(["ok": true])
} else if args.first == "events", args.count == 2 {
    guard AXIsProcessTrusted(), let data = args[1].data(using: .utf8), let events = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { exit(6) }
    let source = CGEventSource(stateID: .hidSystemState)
    var postedButtons = Set<UInt32>()
    var postedKeys = Set<Int>()
    for row in events {
        if let delay = row["wait"] as? Double { guard (0...1).contains(delay) else { exit(7) }; usleep(useconds_t(delay * 1_000_000)); continue }
        guard let raw = row["type"] as? UInt32, let type = CGEventType(rawValue: raw) else { exit(8) }
        let flags = CGEventFlags(rawValue: row["flags"] as? UInt64 ?? 0)
        let buttonID = row["button"] as? UInt32 ?? 0
        let keyID = row["key"] as? Int ?? 58
        let mouseRelease = [.leftMouseUp, .rightMouseUp, .otherMouseUp].contains(type) && postedButtons.contains(buttonID)
        let keyRelease = type == .keyUp && postedKeys.contains(keyID)
        // A press begun on the guarded fixture must release even when its
        // expected action opens the app's own text panel or Settings.
        if !mouseRelease && !keyRelease { guardFocus() }
        let event: CGEvent?
        if [.keyDown, .keyUp, .flagsChanged].contains(type) {
            event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(row["key"] as? Int ?? 58), keyDown: type != .keyUp)
            event?.type = type
            event?.setIntegerValueField(.keyboardEventAutorepeat, value: row["repeat"] as? Bool == true ? 1 : 0)
        } else {
            let p = CGPoint(x: row["x"] as? Double ?? bounds.midX, y: row["y"] as? Double ?? bounds.midY)
            guard bounds.contains(p) else { exit(9) }
            let button = CGMouseButton(rawValue: row["button"] as? UInt32 ?? 0)!
            event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: p, mouseButton: button)
        }
        event?.flags = flags; event?.post(tap: .cghidEventTap)
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type) { postedButtons.insert(buttonID) }
        if mouseRelease { postedButtons.remove(buttonID) }
        if type == .keyDown { postedKeys.insert(keyID) }
        if keyRelease { postedKeys.remove(keyID) }
        usleep(80_000)
    }
    emit(["ok": true])
} else { exit(10) }
