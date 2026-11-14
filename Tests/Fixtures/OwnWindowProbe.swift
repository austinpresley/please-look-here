import AppKit
import ApplicationServices

// Only the isolated app's own UI is inspected or operated here.
let args = Array(CommandLine.arguments.dropFirst())
let env = ProcessInfo.processInfo.environment
guard env["TINYHAND_TEST_MODE"] == "1",
      env["TINYHAND_DEFAULTS_SUITE"]?.hasPrefix("com.austinpresley.tinyhand.fork-upgrades.") == true,
      let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.austinpresley.pleaselookhere.integration").first else { exit(2) }
let root = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(root, 0.5)
func read(_ element: AXUIElement, _ attribute: String) -> Any? {
    var value: CFTypeRef?; AXUIElementCopyAttributeValue(element, attribute as CFString, &value); return value
}
func string(_ element: AXUIElement, _ attribute: String) -> String { String(describing: read(element, attribute) ?? "") }
func children(_ element: AXUIElement) -> [AXUIElement] { read(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
func flatten(_ element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 20, string(element, kAXTitleAttribute) != "Apple" else { return [] }
    return [element] + children(element).flatMap { flatten($0, depth: depth + 1) }
}
func emit(_ value: Any) { print(String(decoding: try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self)) }
let elements = flatten(root)
switch args.first {
case "ax":
    emit(elements.prefix(800).map { ["role": string($0, kAXRoleAttribute), "title": string($0, kAXTitleAttribute),
        "description": string($0, kAXDescriptionAttribute), "value": string($0, kAXValueAttribute)] })
case "close":
    let windows = read(root, kAXWindowsAttribute) as? [AXUIElement] ?? []
    var count = 0
    for window in windows {
        if let button = read(window, kAXCloseButtonAttribute) {
            if AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString) == .success { count += 1 }
        }
    }
    emit(["closed": count])
case "scroll":
    guard args.count == 2, ["top", "bottom"].contains(args[1]) else { exit(2) }
    let bars = elements.filter { string($0, kAXRoleAttribute) == "AXScrollBar" && string($0, kAXOrientationAttribute) == "AXVerticalOrientation" }
    guard let bar = bars.first else { emit(["ok": true, "scrollbar": false]); exit(0) }
    let value = args[1] == "top" ? 0.0 : 1.0
    let result = AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, NSNumber(value: value))
    if result != .success {
        let action = args[1] == "top" ? kAXDecrementAction : kAXIncrementAction
        for _ in 0..<30 { _ = AXUIElementPerformAction(bar, action as CFString); usleep(10_000) }
    }
    usleep(150_000)
    emit(["ok": true, "result": result.rawValue, "value": string(bar, kAXValueAttribute)])
case "press":
    guard args.count == 2 else { exit(2) }
    let candidates = elements.filter { element in
        [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute].contains { string(element, $0) == args[1] }
    }
    for element in candidates {
        var actions: CFArray?
        AXUIElementCopyActionNames(element, &actions)
        if (actions as? [String] ?? []).contains(kAXPressAction) {
            let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
            emit(["ok": result == .success, "result": result.rawValue]); exit(result == .success ? 0 : 1)
        }
    }
    emit(["ok": false, "error": "No matching app-owned press action"]); exit(1)
case "fixture-front":
    guard let fixture = NSRunningApplication.runningApplications(withBundleIdentifier: "com.austinpresley.tinyhand.fixture").first else { exit(2) }
    emit(["ok": fixture.activate(options: [])])
default: exit(2)
}
