import AppKit
import ApplicationServices

final class ControlBridge {
    private let server = ControlServer()
    private let overlay: OverlayController
    private let openSettings: (String?) -> Void
    private let openHandCreator: () -> Void
    private let accessibility: () -> Bool
    private let snapshotSettings: ((String) -> Bool)?
    static var operations: [String] {
        let normal = ["status", "styles", "on", "off", "toggle", "clear", "undo", "redo", "mode", "tool", "capture", "style", "laser", "configure", "toggle-sound", "pin", "settings", "custom-hands"]
        return ProcessInfo.processInfo.environment["TINYHAND_TEST_MODE"] == "1" ? normal + ["snapshot-settings"] : normal
    }

    init(overlay: OverlayController, accessibility: @escaping () -> Bool = { AXIsProcessTrusted() }, openSettings: @escaping (String?) -> Void, openHandCreator: @escaping () -> Void, snapshotSettings: ((String) -> Bool)? = nil) {
        self.overlay = overlay
        self.accessibility = accessibility
        self.openSettings = openSettings
        self.openHandCreator = openHandCreator
        self.snapshotSettings = snapshotSettings
    }

    func start() throws { try server.start { [weak self] data in self?.handle(data) ?? Data() } }
    func stop() { server.stop() }

    struct Problem: Error { let code: String; let message: String }
    private func reject(_ message: String, code: String = "invalid-request") -> Problem {
        Problem(code: code, message: message)
    }

    func handle(_ data: Data) -> Data {
        var response: [String: Any] = ["version": ControlTransport.version]
        do {
            guard let request = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = request["version"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(), version.intValue == 1,
                  version.doubleValue == 1,
                  let op = request["operation"] as? String, Self.operations.contains(op) else {
                throw reject("Unsupported protocol version or operation")
            }
            var allowed: Set<String> = ["version", "operation"]
            if op == "style" { allowed.formUnion(["style", "activate"]) }
            if op == "configure" { allowed.insert("settings") }
            if op == "pin" { allowed.formUnion(["style", "pinned"]) }
            if op == "mode" { allowed.insert("mode") }
            if op == "tool" { allowed.insert("tool") }
            if op == "settings" { allowed.insert("section") }
            if op == "snapshot-settings" { allowed.insert("path") }
            guard Set(request.keys).isSubset(of: allowed) else { throw reject("Unexpected request fields") }
            switch op {
            case "on": try activate()
            case "off": overlay.deactivate()
            case "toggle":
                if overlay.isActive { overlay.deactivate() } else { try activate() }
            case "clear": overlay.clearInk()
            case "undo": overlay.undo()
            case "redo": overlay.redo()
            case "mode":
                guard let value = request["mode"] as? String, let mode = PointerMode(rawValue: value) else { throw reject("Mode must be point or draw") }
                if mode == .draw && !accessibility() { throw reject("Allow Accessibility to draw. Point mode is available without it.", code: "accessibility") }
                guard overlay.setMode(mode) else { throw reject("Drawing is unavailable while capture is pending or permission is missing", code: "unavailable") }
            case "tool":
                guard let value = request["tool"] as? String, let tool = DrawingTool(rawValue: value) else { throw reject("Unknown drawing tool") }
                guard accessibility(), overlay.chooseTool(tool) else { throw reject("Allow Accessibility to use drawing tools", code: "accessibility") }
            case "capture": overlay.captureScreenshot()
            case "style":
                let style = try readStyle(request["style"])
                let shouldActivate = try readBool(request["activate"] ?? false)
                try validateAsset(for: style)
                if shouldActivate { try activate() }
                overlay.pick(style)
                NotificationCenter.default.post(name: Preferences.changed, object: nil)
            case "laser":
                try activate()
                overlay.pick(.laser)
                NotificationCenter.default.post(name: Preferences.changed, object: nil)
            case "configure":
                guard let patch = request["settings"] as? [String: Any], !patch.isEmpty else { throw reject("Settings are required") }
                try configure(patch)
            case "toggle-sound": Preferences.handSound.toggle()
            case "pin":
                let style = try readStyle(request["style"])
                let pinned = try readBool(request["pinned"])
                var styles = Preferences.pinnedStyles
                if pinned && !styles.contains(style) {
                    guard styles.count < Preferences.maxPinned else { throw reject("The toolbar already has eight pointers", code: "toolbar-full") }
                    styles.append(style)
                } else if !pinned {
                    styles.removeAll { $0 == style }
                    guard !styles.isEmpty else { throw reject("Keep at least one pointer pinned") }
                }
                Preferences.pinnedStyles = styles
            case "settings":
                let section = request["section"] as? String
                if request["section"] != nil && (section == nil || SettingsSection(rawValue: section!) == nil) { throw reject("Unknown Settings section") }
                openSettings(section)
            case "custom-hands": openHandCreator()
            case "snapshot-settings":
                guard let path = request["path"] as? String, path.hasPrefix("/"), path.hasSuffix(".png"), snapshotSettings?(path) == true else {
                    throw reject("Focus Settings before taking a verification snapshot", code: "snapshot-failed")
                }
            default: break
            }
            response["ok"] = true
            response["state"] = state()
            if op == "styles" { response["styles"] = styles() }
        } catch {
            let problem = error as? Problem
            response["ok"] = false
            response["error"] = ["code": problem?.code ?? "invalid-request", "message": problem?.message ?? "Malformed control request"]
            response["state"] = state()
        }
        return (try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys])) ?? Data()
    }

    private func activate() throws {
        guard Preferences.pointerMode == .point || accessibility() else { throw reject("Allow Accessibility to draw. Point mode is available without it.", code: "accessibility") }
        let wasActive = overlay.isActive
        guard overlay.activate() else {
            if !wasActive { overlay.deactivate() }
            throw reject("TinyHand could not start intercepting mouse input. Relaunch TinyHand and try again.", code: "activation-failed")
        }
    }

    private func readStyle(_ value: Any?) throws -> PointerStyle {
        guard let id = value as? String, let style = PointerStyle(rawValue: id) else { throw reject("This pointer is no longer available. Refresh the pointer list.", code: "unknown-style") }
        return style
    }

    private func validateAsset(for style: PointerStyle) throws {
        if let asset = style.assetName, HandAsset.load(asset) == nil {
            throw reject("TinyHand could not load the image for this pointer.", code: "missing-asset")
        }
    }

    private func readBool(_ value: Any?) throws -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { throw reject("Expected a boolean") }
        return number.boolValue
    }

    private func readNumber(_ value: Any) throws -> Double {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else { throw reject("Expected a finite number") }
        return number.doubleValue
    }

    /// Validate every field before writing anything; deliver one native settings notification.
    private func configure(_ patch: [String: Any]) throws {
        let allowed: Set<String> = ["style", "ink", "fade", "size", "shadow", "handSound", "laserSound", "tapSound", "lineWidth", "opacity", "smoothing", "motion", "theme", "showToolbar", "captureCopies", "captureSaves", "captureFolder"]
        guard Set(patch.keys).isSubset(of: allowed) else { throw reject("Unsupported setting") }
        let style = try patch["style"].map { try readStyle($0) }
        if let style { try validateAsset(for: style) }
        let ink = patch["ink"].flatMap { ($0 as? String).flatMap(InkChoice.init(rawValue:)) }
        if patch["ink"] != nil && ink == nil { throw reject("Unknown ink color") }
        let sound = patch["tapSound"].flatMap { ($0 as? String).flatMap(TapSoundChoice.init(rawValue:)) }
        if patch["tapSound"] != nil && sound == nil { throw reject("Unknown tap sound") }
        let fade = try patch["fade"].map { try readNumber($0) }
        if let fade = fade, ![0.0, 3, 6, 10].contains(fade) { throw reject("Fade must be 0, 3, 6, or 10 seconds") }
        let size = try patch["size"].map { try readNumber($0) }
        if let size = size, !Preferences.pointerSizeRange.contains(CGFloat(size)) { throw reject("Pointer size is outside the native range") }
        let shadow = try patch["shadow"].map { try readBool($0) }
        let handSound = try patch["handSound"].map { try readBool($0) }
        let laserSound = try patch["laserSound"].map { try readBool($0) }
        let width = try patch["lineWidth"].map { try readNumber($0) }
        if let width = width, !(2...20).contains(width) { throw reject("Line width must be between 2 and 20") }
        let opacity = try patch["opacity"].map { try readNumber($0) }
        if let opacity = opacity, !(0.1...1).contains(opacity) { throw reject("Opacity must be between 0.1 and 1") }
        let smoothing = try patch["smoothing"].map { try readNumber($0) }
        if let smoothing = smoothing, ![0.0, 1, 2, 3].contains(smoothing) { throw reject("Smoothing must be 0, 1, 2 or 3") }
        let motion = patch["motion"].flatMap { ($0 as? String).flatMap(PointerMotion.init(rawValue:)) }
        if patch["motion"] != nil && motion == nil { throw reject("Motion must be original or responsive") }
        let theme = patch["theme"].flatMap { ($0 as? String).flatMap(AppTheme.init(rawValue:)) }
        if patch["theme"] != nil && theme == nil { throw reject("Theme must be system, light or dark") }
        let showToolbar = try patch["showToolbar"].map { try readBool($0) }
        let captureCopies = try patch["captureCopies"].map { try readBool($0) }
        let captureSaves = try patch["captureSaves"].map { try readBool($0) }
        guard (captureCopies ?? Preferences.captureCopies) || (captureSaves ?? Preferences.captureSaves) else { throw reject("Enable clipboard copy or screenshot saving") }
        let captureFolder = patch["captureFolder"] as? String
        if patch["captureFolder"] != nil {
            guard let path = captureFolder, path.hasPrefix("/"), !path.contains("\0") else { throw reject("Capture folder must be an absolute folder path") }
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue { throw reject("Capture folder is a file") }
        }
        Preferences.performBatch {
            if let style = style { PointerStyle.saved = style }
            if let ink = ink { Preferences.inkChoice = ink }
            if let fade = fade { Preferences.fadeSeconds = fade }
            if let size = size { Preferences.pointerSize = CGFloat(size) }
            if let shadow = shadow { Preferences.showShadow = shadow }
            if let handSound = handSound { Preferences.handSound = handSound }
            if let laserSound = laserSound { Preferences.laserSound = laserSound }
            if let sound = sound { Preferences.tapSound = sound }
            if let width = width { Preferences.strokeWidth = CGFloat(width) }
            if let opacity = opacity { Preferences.inkOpacity = CGFloat(opacity) }
            if let smoothing = smoothing { Preferences.strokeSmoothing = StrokeSmoothing(rawValue: Int(smoothing))! }
            if let motion = motion { Preferences.pointerMotion = motion }
            if let theme = theme { Preferences.theme = theme }
            if let showToolbar = showToolbar { Preferences.showToolbar = showToolbar }
            if let captureCopies = captureCopies { Preferences.captureCopies = captureCopies }
            if let captureSaves = captureSaves { Preferences.captureSaves = captureSaves }
            if let captureFolder = captureFolder { Preferences.captureFolder = URL(fileURLWithPath: captureFolder, isDirectory: true) }
        }
    }

    private func state() -> [String: Any] {
        ["running": true, "active": overlay.isActive, "style": overlay.style.rawValue,
         "mode": overlay.mode.rawValue, "tool": Preferences.drawingTool.rawValue, "canUndo": overlay.canUndo, "canRedo": overlay.canRedo,
         "input": overlay.inputDiagnostics,
         "toolbarVisible": overlay.toolbarVisible, "toolbarFrame": [overlay.toolbarFrame.minX, overlay.toolbarFrame.minY, overlay.toolbarFrame.width, overlay.toolbarFrame.height],
         "annotations": overlay.inkStrokes, "capturing": overlay.isCapturing, "motionClock": overlay.motionClock,
         "lastCapture": overlay.lastCaptureURL?.path ?? "", "lastCaptureError": overlay.lastCaptureError ?? "", "captureSize": overlay.lastCaptureSize,
         "accessibility": accessibility(), "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
         "screenRecording": ScreenCapture.hasPermission,
         "windows": NSApp.windows.filter { $0.isVisible && $0.windowNumber > 0 && $0.windowNumber <= Int(UInt32.max) }.prefix(20).map { ["id": $0.windowNumber, "title": $0.title, "width": $0.frame.width, "height": $0.frame.height] as [String: Any] },
         "capabilities": Self.operations,
         "settings": ["ink": Preferences.inkChoice.rawValue, "fade": Preferences.fadeSeconds,
                      "size": Double(Preferences.pointerSize), "shadow": Preferences.showShadow,
                      "handSound": Preferences.handSound, "laserSound": Preferences.laserSound, "tapSound": Preferences.tapSound.rawValue,
                      "lineWidth": Double(Preferences.strokeWidth), "opacity": Double(Preferences.inkOpacity), "smoothing": Preferences.strokeSmoothing.rawValue,
                      "motion": Preferences.pointerMotion.rawValue, "theme": Preferences.theme.rawValue, "showToolbar": Preferences.showToolbar,
                      "captureCopies": Preferences.captureCopies, "captureSaves": Preferences.captureSaves, "captureFolder": Preferences.captureFolder.path,
                      "toolbarPosition": Preferences.toolbarPosition.map { [$0.x, $0.y] } ?? []],
         "sizeRange": [Double(Preferences.pointerSizeRange.lowerBound), Double(Preferences.pointerSizeRange.upperBound)],
         "pinned": Preferences.pinnedStyles.map(\.rawValue)]
    }

    private func styles() -> [[String: Any]] {
        PointerStyle.allCases.map { style in
            var item: [String: Any] = ["id": style.rawValue, "name": style.title, "type": style == .laser ? "laser" : style.isCustom ? "custom" : "hand"]
            // Use TinyHand's own cropped 128px thumbnails, including custom hands.
            if let name = style.assetName, let image = HandAsset.thumbnail(name),
               let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                // Encode the ID rather than treating custom asset IDs as path components.
                let filename = Data(style.rawValue.utf8).map { String(format: "%02x", $0) }.joined() + ".png"
                let url = URL(fileURLWithPath: ControlTransport.directory).appendingPathComponent(filename)
                if (try? png.write(to: url, options: .atomic)) != nil { item["thumbnail"] = url.path }
            }
            return item
        }
    }
}
