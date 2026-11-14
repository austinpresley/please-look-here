import AppKit
import ApplicationServices

// S-023 only: all input is confined to the public fixture or this app's controls.
let env = ProcessInfo.processInfo.environment
let args = Array(CommandLine.arguments.dropFirst())
guard env["TINYHAND_TEST_MODE"] == "1", env["TINYHAND_DEFAULTS_SUITE"]?.hasPrefix("com.austinpresley.tinyhand.s023.") == true,
      let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.austinpresley.pleaselookhere.integration").first,
      let fixture = NSRunningApplication.runningApplications(withBundleIdentifier: "com.austinpresley.tinyhand.fixture").first else { exit(2) }
func windows() -> [[String: Any]] { CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [] }
func emit(_ value: Any) { print(String(decoding: try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self)) }
func read(_ element: AXUIElement, _ attribute: String) -> Any? { var value: CFTypeRef?; AXUIElementCopyAttributeValue(element, attribute as CFString, &value); return value }
func rect(_ element: AXUIElement) -> CGRect? {
    guard let p = read(element, kAXPositionAttribute), let s = read(element, kAXSizeAttribute), CFGetTypeID(p as CFTypeRef) == AXValueGetTypeID(), CFGetTypeID(s as CFTypeRef) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero; var size = CGSize.zero
    AXValueGetValue(p as! AXValue, .cgPoint, &point); AXValueGetValue(s as! AXValue, .cgSize, &size)
    return CGRect(origin: point, size: size)
}
func walk(_ element: AXUIElement, depth: Int = 0, inControls: Bool = false) -> [[String: Any]] {
    guard depth < 14 else { return [] }
    let title = read(element, kAXTitleAttribute) as? String ?? ""
    if title == "Apple" { return [] }
    let description = read(element, kAXDescriptionAttribute) as? String ?? ""
    let frame = rect(element) ?? .zero
    let role = read(element, kAXRoleAttribute) as? String ?? ""
    let withinControls = inControls || role == "AXPopover"
    var row: [String: Any] = ["title": title, "description": description, "role": read(element, kAXRoleAttribute) as? String ?? "", "value": String(describing: read(element, kAXValueAttribute) ?? ""), "enabled": read(element, kAXEnabledAttribute) as? Bool ?? false, "frame": [frame.minX, frame.minY, frame.width, frame.height]]
    if args.first == "press", args.count == 2, frame.width > 0, (withinControls || role == "AXMenuItem" || role == "AXMenuBarItem"), title == args[1] || description == args[1] { row["pressResult"] = AXUIElementPerformAction(element, kAXPressAction as CFString).rawValue }
    var result = [row]
    for child in read(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] { result += walk(child, depth: depth + 1, inControls: withinControls) }
    return result
}
let appAX = AXUIElementCreateApplication(app.processIdentifier)
if args.first == "ax" || args.first == "press" { emit(walk(appAX)) }
else if args.first == "activate-fixture" { emit(["ok": fixture.activate(options: [.activateIgnoringOtherApps])]) }
else if args.first == "state" {
    let all = windows()
    func nativeInput(_ source: CGEventSourceStateID) -> [String: Any] {
        ["flags": CGEventSource.flagsState(source).rawValue, "buttons": (0..<32).filter { CGEventSource.buttonState(source, button: CGMouseButton(rawValue: UInt32($0))!) }]
    }
    let focused = read(appAX, kAXFocusedUIElementAttribute)
    var focus: [String: Any] = [:]
    if let focused, CFGetTypeID(focused as CFTypeRef) == AXUIElementGetTypeID() {
        let element = focused as! AXUIElement
        focus = ["title": read(element, kAXTitleAttribute) as? String ?? "", "description": read(element, kAXDescriptionAttribute) as? String ?? "", "role": read(element, kAXRoleAttribute) as? String ?? "", "value": String(describing: read(element, kAXValueAttribute) ?? "")]
    }
    emit(["focused": focus, "appPID": app.processIdentifier, "frontmost": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "", "appWindows": all.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == app.processIdentifier }, "fixtureWindows": all.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == fixture.processIdentifier }, "combinedInput": nativeInput(.combinedSessionState), "hidInput": nativeInput(.hidSystemState)])
} else if args.first == "shot", args.count == 3, let number = UInt32(args[1]),
          windows().contains(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == app.processIdentifier && ($0[kCGWindowNumber as String] as? UInt32) == number }),
          let image = CGWindowListCreateImage(.null, .optionIncludingWindow, number, [.boundsIgnoreFraming, .bestResolution]),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
    try png.write(to: URL(fileURLWithPath: args[2])); emit(["ok": true])
} else if args.first == "events", args.count == 2, AXIsProcessTrusted(),
          let data = args[1].data(using: .utf8), let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
    let source = CGEventSource(stateID: .hidSystemState)
    for row in rows {
        guard [app.processIdentifier, fixture.processIdentifier].contains(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1),
              windows().contains(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == fixture.processIdentifier && $0[kCGWindowName as String] as? String == "TinyHand test canvas" }),
              let raw = row["type"] as? UInt32, let type = CGEventType(rawValue: raw) else { exit(3) }
        let event: CGEvent?
        if [.keyDown, .keyUp, .flagsChanged].contains(type) {
            event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(row["key"] as? Int ?? 53), keyDown: type != .keyUp)
            if let text = row["text"] as? String {
                let units = Array(text.utf16)
                units.withUnsafeBufferPointer { event?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress) }
            }
            event?.type = type; event?.setIntegerValueField(.keyboardEventAutorepeat, value: row["repeat"] as? Bool == true ? 1 : 0)
        } else {
            guard let x = row["x"] as? Double, let y = row["y"] as? Double else { exit(4) }
            let point = CGPoint(x: x, y: y)
            guard windows().contains(where: { info in
                guard [app.processIdentifier, fixture.processIdentifier].contains(info[kCGWindowOwnerPID as String] as? Int32 ?? -1),
                      let b = info[kCGWindowBounds as String] as? NSDictionary, let rect = CGRect(dictionaryRepresentation: b as CFDictionary) else { return false }
                return rect.contains(point)
            }) else { exit(5) }
            event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: CGMouseButton(rawValue: row["button"] as? UInt32 ?? 0)!)
        }
        event?.flags = CGEventFlags(rawValue: row["flags"] as? UInt64 ?? 0); event?.post(tap: .cghidEventTap); usleep(80_000)
    }
    emit(["ok": true])
} else { exit(6) }
