import AppKit

/// Test-only operations are admitted by ControlBridge only in a disposable
/// review domain. No native events, grants, clipboard or capture are requested.
extension OverlayController {
    func verifyQuickControls(_ request: [String: Any]) throws -> [String: Any] {
        struct Invalid: Error {}
        let allowed: Set<String> = ["surface", "event", "appearance", "size", "editing", "query", "scope", "candidate", "slot", "snapshot"]
        guard Set(request.keys).isSubset(of: allowed), let surface = request["surface"] as? String,
              ["browser", "recovery", "exclusion", "error"].contains(surface) else { throw Invalid() }
        let event = request["event"] as? String ?? "state"
        guard ["open", "state", "close", "finish", "assign", "undo", "dismiss", "edit", "restore", "focus", "focus-dismiss", "undo-key"].contains(event) else { throw Invalid() }
        let events: [String: Set<String>] = ["browser": ["open", "state", "close", "finish", "assign"], "recovery": ["open", "state", "close", "undo", "dismiss", "edit", "focus", "focus-dismiss", "undo-key"], "exclusion": ["open", "state", "close", "restore"], "error": ["open", "state", "close", "dismiss", "focus", "focus-dismiss"]]
        guard events[surface]?.contains(event) == true, event != "assign" || request["slot"] != nil else { throw Invalid() }
        for key in ["surface", "event", "appearance", "query", "candidate", "snapshot"] {
            if let value = request[key], !(value is String) { throw Invalid() }
        }
        if let value = request["editing"] {
            guard let value = value as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { throw Invalid() }
        }
        var size: CGSize?
        if let value = request["size"] {
            guard let a = value as? [NSNumber], a.count == 2, a.allSatisfy({ CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite }),
                  a[0].doubleValue >= 320, a[0].doubleValue <= 1200, a[1].doubleValue >= 180, a[1].doubleValue <= 1000 else { throw Invalid() }
            size = CGSize(width: a[0].doubleValue, height: a[1].doubleValue)
        }
        for (key, range) in [("slot", 0...5), ("scope", 0...1)] {
            if let value = request[key] {
                guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite,
                      number.doubleValue == Double(number.intValue), range.contains(number.intValue) else { throw Invalid() }
            }
        }
        if let candidate = request["candidate"] as? String, !PointerCatalog.entries.contains(where: { $0.style.rawValue == candidate && $0.selectable }) { throw Invalid() }
        if let theme = request["appearance"] as? String, !["light", "dark"].contains(theme) { throw Invalid() }
        if let path = request["snapshot"] as? String {
            guard let root = ProcessInfo.processInfo.environment["APP_SNAPSHOT"], path.hasPrefix("/"), path.hasSuffix(".png"), !path.contains("\0"),
                  URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(URL(fileURLWithPath: root).standardizedFileURL.path + "/") else { throw Invalid() }
        }
        let appearance = (request["appearance"] as? String).flatMap { NSAppearance(named: $0 == "dark" ? .darkAqua : .aqua) }
        let target: NSWindow
        switch surface {
        case "browser":
            target = pointerBrowser.window; if let appearance { target.appearance = appearance }
            if event == "open" { pointerBrowser.close(); pointerBrowser.show(editing: request["editing"] as? Bool ?? false, size: size) }
            else if event == "close" { pointerBrowser.close() }
            pointerBrowser.verify(query: request["query"] as? String, scope: request["scope"] as? Int, candidate: request["candidate"] as? String, finish: event == "finish")
            if event == "assign" { guard let slot = request["slot"] as? Int else { throw Invalid() }; pointerBrowser.verifyAssignment(slot: slot) }
        case "recovery":
            target = clearRecovery.window; if let appearance { target.appearance = appearance }
            if event == "open" { seedClearRecovery() }
            else if event == "dismiss" || event == "close" { clearRecovery.dismissRecovery() }
            else if event == "undo" { clearRecovery.restoreDrawing() }
            else if event == "edit" { verificationDocumentEdit() }
            else if event == "focus" {
                // Invoke the same scoped equivalent handler as the native panel.
                let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .shift], timestamp: 0, windowNumber: radial.window.windowNumber, context: nil, characters: "u", charactersIgnoringModifiers: "u", isARepeat: false, keyCode: 32)!
                guard radial.annotationUndo.performKeyEquivalent(with: key, firstResponder: radial.window.firstResponder) else { throw Invalid() }
            } else if event == "focus-dismiss" {
                guard target.isKeyWindow else { throw Invalid() }
                clearRecovery.verifyDismissFocus()
            } else if event == "undo-key" {
                let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: target.windowNumber, context: nil, characters: "z", charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6)!
                guard target.performKeyEquivalent(with: key) else { throw Invalid() }
            }
        case "error":
            target = commandError.window; if let appearance { target.appearance = appearance }
            if event == "open" { commandError.show(.capture(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [NSLocalizedDescriptionKey: "The screenshot folder is read-only. Choose another folder and try again."]))) }
            else if event == "close" || event == "dismiss" { commandError.dismiss() }
            else if event == "focus" || event == "focus-dismiss" { commandError.verifyFocus(dismiss: event == "focus-dismiss") }
        default:
            if event == "open" { beginCaptureExclusion() }
            else if event == "restore" || event == "close" { finishCaptureExclusion() }
            target = CaptureExclusionWitness.shared.window
            if let appearance { target.appearance = appearance }
            CaptureExclusionWitness.shared.show(captureDiagnostics)
        }
        if let path = request["snapshot"] as? String {
            guard target.isVisible,
                  let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(target.windowNumber), [.boundsIgnoreFraming, .bestResolution]),
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw Invalid() }
            try data.write(to: URL(fileURLWithPath: path))
            let state = ["browser": pointerBrowser.diagnostics, "recovery": clearRecovery.diagnostics, "capture": captureDiagnostics, "error": commandError.diagnostics]
            try JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: path.replacingOccurrences(of: ".png", with: "-layout.json")))
        }
        return ["browser": pointerBrowser.diagnostics, "recovery": clearRecovery.diagnostics, "capture": captureDiagnostics, "error": commandError.diagnostics]
    }
}

/// A diagnostic view of real pre-capture visibility, not a desktop screenshot.
/// The witness is never shown by the production capture path.
private final class CaptureExclusionWitness {
    static let shared = CaptureExclusionWitness()
    let window = NSPanel(contentRect: CGRect(x: 400, y: 400, width: 560, height: 240), styleMask: [.titled], backing: .buffered, defer: false)
    let label = NSTextField(wrappingLabelWithString: "")
    init() {
        window.title = "Pre-capture visibility verification"; window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular); label.frame = CGRect(x: 24, y: 24, width: 512, height: 192)
        window.contentView?.addSubview(label)
    }
    func show(_ state: [String: Any]) {
        let recovery = state["recovery"] as? [String: Any] ?? [:]
        label.stringValue = "Pre-capture visibility\n\nWheel, marker, arming cue and list: \(state["wheelVisible"] as? Bool == true ? "VISIBLE" : "hidden")\nPointer browser: \(state["browserVisible"] as? Bool == true ? "VISIBLE" : "hidden")\nScreenshot result: \(state["resultVisible"] as? Bool == true ? "VISIBLE" : "hidden")\nClear recovery: \(recovery["visible"] as? Bool == true ? "VISIBLE" : "hidden"), state retained: \(recovery["valid"] as? Bool == true)\n\nDiagnostic fixture. No screen capture performed."
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
