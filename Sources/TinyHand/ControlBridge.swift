import AppKit
import ApplicationServices

final class ControlBridge {
    private let server = ControlServer()
    private let overlay: OverlayController
    private let openSettings: (String?) -> Void
    private let openHandCreator: () -> Void
    private let accessibility: () -> Bool
    var verifyMenuBar: (([String: Any]) -> [String: Any])?
    var verifyShortcuts: (([String: Any]) -> [String: Any])?
    private let snapshotSettings: ((String) -> Bool)?
    static var operations: [String] {
        let normal = ["status", "styles", "cycle-pointer", "cycle-tool", "enable-pointer", "on", "off", "toggle", "clear", "undo", "redo", "interact", "mode", "tool", "capture", "capture-region", "magnifier", "gesture", "style", "laser", "configure", "toggle-sound", "toggle-current-sound", "pin", "settings", "custom-hands"]
        return ProcessInfo.processInfo.environment["TINYHAND_TEST_MODE"] == "1" ? normal + ["snapshot-settings", "run-applescript", "test-shortcuts", "test-radial", "test-menu-bar", "test-presentation"] : normal
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
            if op == "enable-pointer" { allowed.formUnion(["style", "enabled"]) }
            if op == "mode" { allowed.insert("mode") }
            if op == "interact" { allowed.insert("enabled") }
            if op == "magnifier" { allowed.insert("enabled") }
            if op == "gesture" { allowed.insert("slot") }
            if op == "tool" { allowed.insert("tool") }
            if op == "settings" { allowed.insert("section") }
            if op == "snapshot-settings" { allowed.insert("path") }
            if op == "run-applescript" { allowed.insert("source") }
            if op == "test-shortcuts" || op == "test-radial" || op == "test-menu-bar" { allowed.insert("request") }
            if op == "test-presentation" { allowed.insert("request") }
            guard Set(request.keys).isSubset(of: allowed) else { throw reject("Unexpected request fields") }
            switch op {
            case "on": try activate()
            case "off": overlay.deactivate()
            case "toggle":
                if overlay.isActive { overlay.deactivate() } else { try activate() }
            case "clear": overlay.clearInk()
            case "undo": overlay.undo()
            case "redo": overlay.redo()
            case "mode", "interact":
                let mode: PointerMode
                if op == "interact" {
                    mode = try readBool(request["enabled"]) ? .point : .draw
                } else {
                    guard let value = request["mode"] as? String, let storedMode = PointerMode(rawValue: value) else { throw reject("Legacy mode must be point or draw; use interact with an enabled boolean") }
                    mode = storedMode
                }
                if mode == .draw && !accessibility() { throw reject("Allow Accessibility to draw. Interact is available without it.", code: "accessibility") }
                guard overlay.setMode(mode) else { throw reject("Drawing is unavailable while capture is pending or permission is missing", code: "unavailable") }
            case "tool":
                guard let value = request["tool"] as? String, let tool = DrawingTool(rawValue: value) else { throw reject("Unknown drawing tool") }
                try selectTool(tool)
            case "cycle-tool":
                // The server serializes handlers on the main queue. Resolve the
                // current tool here, never from a plugin's earlier observation.
                try selectTool(Preferences.drawingTool.next)
            case "capture": overlay.captureScreenshot()
            case "capture-region": overlay.captureRegion()
            case "magnifier":
                let enabled = try readBool(request["enabled"])
                if enabled && overlay.isCapturing { throw reject("Magnification is unavailable while a screenshot is pending.", code: "unavailable") }
                guard overlay.setMagnification(enabled) else {
                    throw reject(overlay.lastMagnifierError ?? "Magnification is unavailable while a screenshot is pending.", code: overlay.lastMagnifierError == nil ? "unavailable" : "screen-recording")
                }
            case "gesture":
                if request["slot"] as? String == "none" { overlay.cancelHandGestures() }
                else {
                    guard let raw = request["slot"] as? String, let slot = HandGestureSlot(rawValue: raw) else { throw reject("Gesture slot must be first, second or none") }
                    guard overlay.previewGesture(slot) else { throw reject("Choose an available hand and close Settings or capture before showing a gesture.", code: "unavailable") }
                }
            case "style":
                let style = try readStyle(request["style"])
                let shouldActivate = try readBool(request["activate"] ?? false)
                try validateAsset(for: style)
                if shouldActivate { try activate() }
                overlay.pick(style)
                NotificationCenter.default.post(name: Preferences.changed, object: nil)
            case "cycle-pointer":
                // ControlServer executes this entire operation on the main queue.
                // Refresh manifest membership before resolving the current catalog.
                CustomHands.reload()
                let next = try PointerCatalog.nextSelectable(after: overlay.style)
                guard overlay.pick(next) else {
                    throw reject("The pointer image became unavailable. Restore it or choose another pointer.", code: "missing-asset")
                }
                NotificationCenter.default.post(name: Preferences.changed, object: nil)
            case "laser":
                try validateAsset(for: .laser)
                try activate()
                overlay.pick(.laser)
                NotificationCenter.default.post(name: Preferences.changed, object: nil)
            case "enable-pointer":
                let style = try readStyle(request["style"])
                try PointerCatalog.setEnabled(try readBool(request["enabled"]), for: style)
            case "configure":
                guard let patch = request["settings"] as? [String: Any], !patch.isEmpty else { throw reject("Settings are required") }
                try configure(patch)
            case "test-radial":
                guard ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"]?.hasPrefix("com.austinpresley.tinyhand.s013.") == true,
                      let request = request["request"] as? [String: Any] else { throw reject("Use an isolated S-013 suite") }
                if let policy = request["releaseSelects"] as? Bool { overlay.radial.releaseSelects = policy }
                if let path = request["snapshot"] as? String, !overlay.radial.snapshot(to: path) { throw reject("Radial snapshot failed") }
                response["radial"] = overlay.radial.diagnostics
            case "toggle-current-sound": overlay.soundOn.toggle()
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
            case "test-menu-bar":
                guard ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"]?.hasPrefix("com.austinpresley.tinyhand.s023.") == true,
                      let request = request["request"] as? [String: Any], let verifyMenuBar else { throw reject("Use an isolated S-023 suite") }
                response["controls"] = verifyMenuBar(request)
            case "test-shortcuts":
                guard let request = request["request"] as? [String: Any], let verifyShortcuts else { throw reject("Shortcut test request is required") }
                response["shortcuts"] = verifyShortcuts(request)
            case "test-presentation":
                guard ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"]?.hasPrefix("com.austinpresley.tinyhand.fork-upgrades.") == true,
                      let request = request["request"] as? [String: Any], let event = request["event"] as? String else { throw reject("Use an isolated fork-upgrades suite") }
                switch event {
                case "sleep": NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
                case "screenSleep": NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
                case "session": NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
                case "space": NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
                case "display": NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
                case "lock", "screensaver": overlay.stopForSystem("simulated \(event)")
                case "snapshot":
                    guard let path = request["path"] as? String, let root = ProcessInfo.processInfo.environment["APP_SNAPSHOT"],
                          path.hasSuffix(".png"), URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(URL(fileURLWithPath: root).standardizedFileURL.path + "/") else { throw reject("Use a PNG inside the test snapshot directory") }
                    overlay.snapshotPresentation(to: URL(fileURLWithPath: path))
                default: throw reject("Unknown presentation test event")
                }
            case "run-applescript":
                // Test mode only. A process addressing itself needs no Automation consent.
                guard let source = request["source"] as? String, let script = NSAppleScript(source: source) else { throw reject("Script source is required") }
                var failure: NSDictionary?
                let result = script.executeAndReturnError(&failure)
                response["script"] = ["result": failure == nil ? describeScriptResult(result) : "", "errorNumber": failure?[NSAppleScript.errorNumber] as? Int ?? 0, "errorMessage": failure?[NSAppleScript.errorMessage] as? String ?? ""] as [String: Any]
            default: break
            }
            response["ok"] = true
            response["state"] = state()
            if op == "styles" { response["styles"] = styles() }
        } catch {
            let problem = error as? Problem
            let catalogProblem = error as? PointerCatalog.Problem
            response["ok"] = false
            response["error"] = ["code": problem?.code ?? catalogProblem?.code ?? "invalid-request", "message": problem?.message ?? catalogProblem?.message ?? "Malformed control request"]
            response["state"] = state()
        }
        return (try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys])) ?? Data()
    }

    private func describeScriptResult(_ descriptor: NSAppleEventDescriptor) -> String {
        guard descriptor.numberOfItems > 0, descriptor.descriptorType == typeAEList else {
            if descriptor.descriptorType == typeTrue || descriptor.descriptorType == typeFalse || descriptor.descriptorType == typeBoolean { return descriptor.booleanValue ? "true" : "false" }
            return descriptor.stringValue ?? String(descriptor.typeCodeValue)
        }
        return "{" + (1...descriptor.numberOfItems).compactMap { descriptor.atIndex($0).map(describeScriptResult) }.joined(separator: ", ") + "}"
    }

    private func activate() throws {
        guard Preferences.pointerMode == .point || accessibility() else { throw reject("Allow Accessibility to draw. Interact is available without it.", code: "accessibility") }
        let wasActive = overlay.isActive
        guard overlay.activate() else {
            if !wasActive { overlay.deactivate() }
            throw reject("Look Here Please could not start intercepting mouse input. Relaunch Look Here Please and try again.", code: "activation-failed")
        }
    }

    private func selectTool(_ tool: DrawingTool) throws {
        guard !overlay.isCapturing else { throw reject("Wait for the screenshot to finish before changing drawing tools", code: "capturing") }
        guard accessibility() else { throw reject("Allow Accessibility to use drawing tools", code: "accessibility") }
        guard overlay.chooseTool(tool) else { throw reject("Drawing input could not start. Check Accessibility and try again.", code: "unavailable") }
    }

    private func readStyle(_ value: Any?) throws -> PointerStyle {
        guard let id = value as? String, let style = PointerStyle(rawValue: id) else { throw reject("This pointer is no longer available. Refresh the pointer list.", code: "unknown-style") }
        return style
    }

    private func validateAsset(for style: PointerStyle) throws {
        try PointerCatalog.validateSelection(style)
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
        let allowed: Set<String> = ["style", "ink", "fade", "size", "shadow", "shadowStyle", "handSound", "laserSound", "tapSound", "lineWidth", "opacity", "smoothing", "motion", "theme", "showToolbar", "interactKeepsHand", "captureCopies", "captureSaves", "captureFolder", "radialTrigger", "inkFadeStyle", "trailDelay", "trailSpeed", "magnifierZoom", "magnifierDiameter", "tapSwing"]
        guard Set(patch.keys).isSubset(of: allowed) else { throw reject("Unsupported setting") }
        var trigger: RadialTrigger?
        if let value = patch["radialTrigger"] {
            guard let id = value as? String, id.isEmpty || RadialTrigger(rawValue: id) != nil else { throw reject("Radial trigger must be empty, option, control, shift or command") }
            trigger = RadialTrigger(rawValue: id)
        }
        let style = try patch["style"].map { try readStyle($0) }
        if let style { try validateAsset(for: style) }
        let ink = patch["ink"].flatMap { ($0 as? String).flatMap(InkChoice.init(rawValue:)) }
        if patch["ink"] != nil && ink == nil { throw reject("Unknown ink color") }
        let sound = patch["tapSound"].flatMap { ($0 as? String).flatMap(TapSoundChoice.init(rawValue:)) }
        if patch["tapSound"] != nil && sound == nil { throw reject("Unknown tap sound") }
        let fade = try patch["fade"].map { try readNumber($0) }
        if let fade = fade, ![0.0, 3, 6, 10].contains(fade) { throw reject("Fade must be 0, 3, 6, or 10 seconds") }
        let fadeStyle = patch["inkFadeStyle"].flatMap { ($0 as? String).flatMap(InkFadeStyle.init(rawValue:)) }
        if patch["inkFadeStyle"] != nil && fadeStyle == nil { throw reject("Ink fading must be wholeLine, trail or permanent") }
        let trailDelay = try patch["trailDelay"].map { try readNumber($0) }
        if let trailDelay, !(0.2...3).contains(trailDelay) { throw reject("Trail delay must be between 0.2 and 3 seconds") }
        let trailSpeed = try patch["trailSpeed"].map { try readNumber($0) }
        if let trailSpeed, !(40...600).contains(trailSpeed) { throw reject("Trail speed must be between 40 and 600 points per second") }
        let zoom = try patch["magnifierZoom"].map { try readNumber($0) }
        if let zoom, !(1.5...6).contains(zoom) { throw reject("Magnification zoom must be between 1.5 and 6") }
        let diameter = try patch["magnifierDiameter"].map { try readNumber($0) }
        if let diameter, !(160...480).contains(diameter) { throw reject("Magnification lens size must be between 160 and 480 points") }
        let tapSwing = try patch["tapSwing"].map { try readNumber($0) }
        if let tapSwing, !(0...2).contains(tapSwing) { throw reject("Tap swing must be between 0 and 2") }
        let size = try patch["size"].map { try readNumber($0) }
        if let size = size, !Preferences.pointerSizeRange.contains(CGFloat(size)) { throw reject("Pointer size is outside the native range") }
        let shadow = try patch["shadow"].map { try readBool($0) }
        let shadowStyle = patch["shadowStyle"].flatMap { ($0 as? String).flatMap(PointerShadowStyle.init(rawValue:)) }
        if patch["shadowStyle"] != nil && shadowStyle == nil { throw reject("Unknown shadow style") }
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
        let keepsHand = try patch["interactKeepsHand"].map { try readBool($0) }
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
            if patch["radialTrigger"] != nil { Preferences.radialTrigger = trigger }
            if let style = style { PointerStyle.saved = style }
            if let ink = ink { Preferences.inkChoice = ink }
            if let fade = fade {
                Preferences.fadeSeconds = fade
                if fadeStyle == nil { Preferences.inkFadeStyle = fade <= 0 ? .permanent : .wholeLine }
            }
            if let fadeStyle { Preferences.inkFadeStyle = fadeStyle }
            if let trailDelay { Preferences.trailDelay = trailDelay }
            if let trailSpeed { Preferences.trailSpeed = trailSpeed }
            if let zoom { Preferences.magnifierZoom = zoom }
            if let diameter { Preferences.magnifierDiameter = diameter }
            if let tapSwing { Preferences.tapSwing = tapSwing }
            if let size = size { Preferences.pointerSize = CGFloat(size) }
            if let shadow = shadow { Preferences.showShadow = shadow }
            if let shadowStyle { Preferences.shadowStyle = shadowStyle }
            if let handSound = handSound { Preferences.handSound = handSound }
            if let laserSound = laserSound { Preferences.laserSound = laserSound }
            if let sound = sound { Preferences.tapSound = sound }
            if let width = width { Preferences.strokeWidth = CGFloat(width) }
            if let opacity = opacity { Preferences.inkOpacity = CGFloat(opacity) }
            if let smoothing = smoothing { Preferences.strokeSmoothing = StrokeSmoothing(rawValue: Int(smoothing))! }
            if let motion = motion { Preferences.pointerMotion = motion }
            if let theme = theme { Preferences.theme = theme }
            if let showToolbar = showToolbar { Preferences.showToolbar = showToolbar }
            if let keepsHand = keepsHand { Preferences.interactKeepsHand = keepsHand }
            if let captureCopies = captureCopies { Preferences.captureCopies = captureCopies }
            if let captureSaves = captureSaves { Preferences.captureSaves = captureSaves }
            if let captureFolder = captureFolder { Preferences.captureFolder = URL(fileURLWithPath: captureFolder, isDirectory: true) }
        }
    }

    private func state() -> [String: Any] {
        ["running": true, "active": overlay.isActive, "style": overlay.style.rawValue,
         "mode": overlay.mode.rawValue, "interact": overlay.mode.isInteractive, "pointerVisible": overlay.pointerVisible,
         "onActiveSpace": overlay.onActiveSpace,
         "tool": Preferences.drawingTool.rawValue, "canUndo": overlay.canUndo, "canRedo": overlay.canRedo,
         "input": overlay.inputDiagnostics,
         "toolbarVisible": overlay.toolbarVisible, "toolbarFrame": [overlay.toolbarFrame.minX, overlay.toolbarFrame.minY, overlay.toolbarFrame.width, overlay.toolbarFrame.height],
         "annotations": overlay.inkStrokes, "capturing": overlay.isCapturing, "motionClock": overlay.motionClock,
         "selectingCaptureRegion": overlay.isSelectingScreenshotRegion,
         "shadowRendering": overlay.shadowDiagnostics,
         "magnifying": overlay.isMagnifying, "magnifier": overlay.magnifierDiagnostics, "lastMagnifierError": overlay.lastMagnifierError ?? "",
         "gesture": overlay.activeGesture?.rawValue ?? "",
         "contactSoundPending": overlay.contactSoundPending,
         "lastCapture": overlay.lastCaptureURL?.path ?? "", "lastCaptureError": overlay.lastCaptureError ?? "", "captureSize": overlay.lastCaptureSize,
         "accessibility": accessibility(), "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
         "screenRecording": ScreenCapture.hasPermission,
         "windows": NSApp.windows.filter { $0.isVisible && $0.windowNumber > 0 && $0.windowNumber <= Int(UInt32.max) }.prefix(20).map { ["id": $0.windowNumber, "title": $0.title, "width": $0.frame.width, "height": $0.frame.height] as [String: Any] },
         "capabilities": Self.operations,
         "radial": overlay.radial.diagnostics,
         "settings": ["radialTrigger": Preferences.radialTrigger?.rawValue ?? "", "ink": Preferences.inkChoice.rawValue, "fade": Preferences.fadeSeconds,
                      "inkFadeStyle": Preferences.inkFadeStyle.rawValue, "trailDelay": Preferences.trailDelay, "trailSpeed": Preferences.trailSpeed,
                      "magnifierZoom": Preferences.magnifierZoom, "magnifierDiameter": Preferences.magnifierDiameter,
                      "tapSwing": Preferences.tapSwing,
                      "size": Double(Preferences.pointerSize), "shadow": Preferences.showShadow,
                      "shadowStyle": Preferences.shadowStyle.rawValue,
                      "handSound": Preferences.handSound, "laserSound": Preferences.laserSound, "tapSound": Preferences.tapSound.rawValue,
                      "lineWidth": Double(Preferences.strokeWidth), "opacity": Double(Preferences.inkOpacity), "smoothing": Preferences.strokeSmoothing.rawValue,
                      "motion": Preferences.pointerMotion.rawValue, "theme": Preferences.theme.rawValue, "showToolbar": Preferences.showToolbar,
                      "interactKeepsHand": Preferences.interactKeepsHand,
                      "captureCopies": Preferences.captureCopies, "captureSaves": Preferences.captureSaves, "captureFolder": Preferences.captureFolder.path,
                      "toolbarPosition": Preferences.toolbarPosition.map { [$0.x, $0.y] } ?? []],
         "shortcuts": Preferences.shortcutState,
         "sizeRange": [Double(Preferences.pointerSizeRange.lowerBound), Double(Preferences.pointerSizeRange.upperBound)],
         "enabledPointers": PointerCatalog.selectableStyles.map(\.rawValue),
         "quickPointers": PointerCatalog.quickStyles.map(\.rawValue),
         "disabledPointers": Preferences.disabledPointerIDs.sorted(),
         "pinned": Preferences.pinnedStyles.map(\.rawValue)]
    }

    private func styles() -> [[String: Any]] {
        PointerCatalog.entries.map { entry in
            let style = entry.style
            var item: [String: Any] = ["id": style.rawValue, "name": style.title, "type": style.catalogType,
                                       "enabled": entry.enabled, "available": entry.available, "selectable": entry.selectable,
                                       "pinned": Preferences.pinnedStyles.contains(style)]
            // Use Look Here Please's own cropped 128px thumbnails, including custom hands.
            if entry.available, let image = Toolbar.icon(for: style),
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
