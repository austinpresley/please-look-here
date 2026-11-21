import AppKit

/// Called only by the disposable-suite test-menu-bar operation. Captures one
/// app-owned window; never synthesizes input or changes permission grants.
enum UsabilityVerification {
    static func capture(_ window: NSWindow?, request: [String: Any]) -> [String: Any] {
        guard let window else { return ["visible": false] }
        if let theme = request["appearance"] as? String, ["light", "dark"].contains(theme) {
            let name: NSAppearance.Name = theme == "dark" ? .darkAqua : .aqua
            if NSApp.appearance?.name != name { NSApp.appearance = NSAppearance(named: name) }
            if window.appearance?.name != name { window.appearance = NSAppearance(named: name) }
        }
        window.contentView?.layoutSubtreeIfNeeded(); window.displayIfNeeded()
        var result: [String: Any] = ["visible": window.isVisible, "key": window.isKeyWindow,
            "window": window.windowNumber, "size": [window.frame.width, window.frame.height]]
        if let path = request["snapshot"] as? String,
           let root = ProcessInfo.processInfo.environment["APP_SNAPSHOT"], path.hasSuffix(".png"),
           URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(URL(fileURLWithPath: root).standardizedFileURL.path + "/"),
           window.isVisible,
           let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]),
           let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            do { try data.write(to: URL(fileURLWithPath: path)); result["snapshot"] = path }
            catch { result["error"] = error.localizedDescription }
        }
        return result
    }
}
