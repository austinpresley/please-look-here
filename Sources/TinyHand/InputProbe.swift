import AppKit
import Carbon.HIToolbox

/// Local verification entry point. Sends system events only over the dedicated fixture.
enum InputProbe {
    static func run(_ arguments: [String]) -> Int32 {
        guard ProcessInfo.processInfo.environment["TINYHAND_TEST_MODE"] == "1" else { return 2 }
        guard let fixture = NSRunningApplication.runningApplications(withBundleIdentifier: "com.austinpresley.tinyhand.fixture").first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              windows.contains(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == fixture.processIdentifier }) else {
            print("No visible test fixture; no input was posted")
            return 2
        }
        let fixtureBounds = windows.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == fixture.processIdentifier }.compactMap { info -> CGRect? in
            guard let value = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: value as CFDictionary)
        }
        let source = CGEventSource(stateID: .hidSystemState)
        func mouse(_ type: CGEventType, _ point: CGPoint, flags: CGEventFlags = []) {
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
            usleep(30_000)
        }
        guard let command = arguments.first else { return 2 }
        switch command {
        case "move":
            let numbers = arguments.dropFirst().compactMap(Double.init)
            guard numbers.count == 2, numbers.allSatisfy(\.isFinite) else { return 2 }
            let point = CGPoint(x: numbers[0], y: numbers[1])
            guard fixtureBounds.contains(where: { $0.contains(point) }) else { return 2 }
            mouse(.mouseMoved, point)
        case "drag", "click", "control-click", "hold":
            let numbers = arguments.dropFirst().compactMap(Double.init)
            let count = command == "drag" ? 4 : command == "hold" ? 3 : 2
            guard numbers.count == count, numbers.allSatisfy(\.isFinite) else { return 2 }
            if command == "hold", !(0.1...5).contains(numbers[2]) { return 2 }
            let start = CGPoint(x: numbers[0], y: numbers[1])
            guard fixtureBounds.contains(where: { $0.contains(start) }) else { return 2 }
            if command == "drag", !fixtureBounds.contains(where: { $0.contains(CGPoint(x: numbers[2], y: numbers[3])) }) { return 2 }
            mouse(.mouseMoved, start)
            let flags: CGEventFlags = command == "control-click" ? .maskControl : []
            mouse(.leftMouseDown, start, flags: flags)
            if command == "drag" {
                let end = CGPoint(x: numbers[2], y: numbers[3])
                for i in 1...16 {
                    let t = CGFloat(i) / 16
                    mouse(.leftMouseDragged, CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t))
                }
                mouse(.leftMouseUp, end)
            } else {
                if command == "hold" { usleep(useconds_t(numbers[2] * 1_000_000)) }
                mouse(.leftMouseUp, start, flags: flags)
            }
        case "key", "key-hold", "key-release-modifiers", "gesture-overlap", "release-keys":
            guard (command != "key" || arguments.count == 2),
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == fixture.processIdentifier else {
                print("Fixture is not frontmost; no key was posted")
                return 2
            }
            let name = arguments.count > 1 ? arguments[1] : "gesture1"
            guard let action = PresentationAction(rawValue: name), let shortcut = Preferences.shortcut(for: action) else {
                print("Shortcut is unassigned; no key was posted")
                return 2
            }
            let modifiers: [(Int, UInt32, CGEventFlags)] = [(kVK_Control, UInt32(controlKey), .maskControl), (kVK_Option, UInt32(optionKey), .maskAlternate), (kVK_Shift, UInt32(shiftKey), .maskShift), (kVK_Command, UInt32(cmdKey), .maskCommand)]
            let duration = arguments.count > 2 ? Double(arguments[2]) ?? -1 : 1
            guard (0.1...5).contains(duration) else { return 2 }
            let overlap = Preferences.shortcut(for: .gesture2)
            if command == "gesture-overlap", overlap == nil || overlap?.modifiers != shortcut.modifiers { return 2 }
            func key(_ code: UInt32, down: Bool, flags: CGEventFlags) {
                let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: down)
                event?.flags = flags; event?.post(tap: .cghidEventTap); usleep(30_000)
            }
            func stage(_ text: String) { FileHandle.standardOutput.write(Data("STAGE \(text)\n".utf8)) }
            var held: CGEventFlags = []
            if command == "release-keys" {
                for slot in HandGestureSlot.allCases {
                    if let value = Preferences.shortcut(for: slot.action) { key(value.keyCode, down: false, flags: []) }
                }
                for (code, _, _) in modifiers {
                    let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: false)
                    event?.type = .flagsChanged; event?.flags = []; event?.post(tap: .cghidEventTap)
                }
                return 0
            }
            for (code, mask, flag) in modifiers where shortcut.modifiers & mask != 0 {
                held.insert(flag)
                let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: true)
                event?.type = .flagsChanged; event?.flags = held; event?.post(tap: .cghidEventTap)
            }
            key(shortcut.keyCode, down: true, flags: held)
            stage("down")
            if command == "gesture-overlap", let other = overlap {
                usleep(400_000); key(other.keyCode, down: true, flags: held); stage("second")
                usleep(400_000); key(shortcut.keyCode, down: false, flags: held); stage("second-after-first-release")
                usleep(400_000); key(other.keyCode, down: false, flags: held); stage("released")
            } else {
                if command == "key-hold" || command == "key-release-modifiers" { usleep(useconds_t(duration * 1_000_000)) }
                if command == "key-release-modifiers" {
                    for (code, mask, flag) in modifiers.reversed() where shortcut.modifiers & mask != 0 {
                        held.remove(flag)
                        let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: false)
                        event?.type = .flagsChanged; event?.flags = held; event?.post(tap: .cghidEventTap)
                    }
                    stage("modifiers-up"); usleep(400_000)
                }
                key(shortcut.keyCode, down: false, flags: held)
                stage("released")
            }
            for (code, mask, flag) in modifiers.reversed() where shortcut.modifiers & mask != 0 {
                held.remove(flag)
                let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: false)
                event?.type = .flagsChanged; event?.flags = held; event?.post(tap: .cghidEventTap)
            }
        default: return 2
        }
        print("Posted fixture input: \(arguments.joined(separator: " "))")
        return 0
    }
}
