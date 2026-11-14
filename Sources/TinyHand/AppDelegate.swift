import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlay = OverlayController(accessibility: {
        let env = ProcessInfo.processInfo.environment
        return env["TINYHAND_TEST_MODE"] == "1" && env["TINYHAND_TEST_DENY_ACCESSIBILITY"] == "1" ? false : AXIsProcessTrusted()
    })
    private let settings = SettingsWindow()
    private let updater = Updater()
    private let welcome = WelcomeWindow()
    private lazy var menuBar = MenuBarControls(overlay: overlay, perform: { [weak self] request in
        guard let self, let data = try? JSONSerialization.data(withJSONObject: request),
              let response = try? JSONSerialization.jsonObject(with: self.control.handle(data)) as? [String: Any] else { return "Action unavailable" }
        return response["ok"] as? Bool == true ? "" : ((response["error"] as? [String: Any])?["message"] as? String ?? "Action unavailable")
    }, checkForUpdates: { [weak self] in self?.updater.checkForUpdates() })
    private var hotKeys: [UInt32] = []
    private var keySignature = ""
    private var recordingShortcut = false
    private var observer: Any?
    lazy var control = ControlBridge(overlay: overlay, accessibility: {
        // Lets a test instance exercise real rejection paths without revoking the grant.
        let env = ProcessInfo.processInfo.environment
        return env["TINYHAND_TEST_MODE"] == "1" && env["TINYHAND_TEST_DENY_ACCESSIBILITY"] == "1" ? false : AXIsProcessTrusted()
    }, openSettings: { [weak self] section in self?.openSettings(section.flatMap(SettingsSection.init(rawValue:))) },
                                             openHandCreator: { [weak self] in self?.settings.showHandCreator() },
                                             snapshotSettings: { [weak self] in self?.settings.exportVerificationSnapshot(to: $0) ?? false })

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = editingMenu()
        HandAsset.preloadThumbnails(PointerStyle.allCases.compactMap(\.assetName))
        CursorHider.enableBackgroundHiding()
        overlay.onActiveChanged = { [weak self] in self?.menuBar.refresh(); _ = self?.registerHotKeys() }
        overlay.onSoundChanged = { [weak self] in self?.menuBar.refresh() }
        overlay.onShortcutContextChanged = { [weak self] in _ = self?.registerHotKeys() }
        overlay.extraPassThrough = { [weak self] in self?.menuBar.statusFrame.map { [$0] } ?? [] }
        overlay.onNeedsPermission = { [weak self] in self?.welcome.show(forDrawing: true) }
        welcome.onTryIt = { [weak self] mode in
            guard let self = self, self.overlay.setMode(mode) else { return }
            _ = self.overlay.activate()
        }
        overlay.radial.perform = { [weak self] request in
            guard let self, let data = try? JSONSerialization.data(withJSONObject: request),
                  let response = try? JSONSerialization.jsonObject(with: self.control.handle(data)) as? [String: Any] else { return "Action unavailable" }
            return response["ok"] as? Bool == true ? "Selected" : ((response["error"] as? [String: Any])?["message"] as? String ?? "Action unavailable")
        }
        menuBar.start()
        overlay.onDismissControls = { [weak self] in self?.menuBar.close() }
        overlay.onControlStatusClick = { [weak self] in self?.menuBar.statusClickFromTap(secondary: $0) }
        control.verifyMenuBar = { [weak self] in self?.menuBar.verify($0) ?? [:] }
        setupSettings()
        applyTheme()
        observer = NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [weak self] _ in
            self?.applyTheme()
            self?.menuBar.refresh()
            _ = self?.registerHotKeys()
        }
        _ = registerHotKeys()
        updater.start()
        control.verifyShortcuts = { [weak self] in self?.verifyShortcuts($0) ?? [:] }
        do { try control.start() } catch { Log.write("local control unavailable: \(error.localizedDescription)") }
        if ProcessInfo.processInfo.environment["TINYHAND_TEST_MODE"] != "1" {
            if !UserDefaults.standard.bool(forKey: WelcomeWindow.shownKey) { welcome.show() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        control.stop()
        unregisterHotKeys()
        overlay.deactivate()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let current = NSApp.keyWindow, current.isVisible {
            current.makeKeyAndOrderFront(nil)
            return false
        }
        openSettings()
        return false
    }
    private func applyTheme() {
        switch Preferences.theme {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func setupSettings() {
        settings.applyToggleShortcut = { [weak self] value in self?.apply(value, action: nil, toggle: true) ?? false }
        settings.applyClearShortcut = { [weak self] value in self?.apply(value, action: nil, toggle: false) ?? false }
        settings.applyPresentationShortcut = { [weak self] action, value in self?.apply(value, action: action, toggle: false) ?? false }
        settings.applyMode = { [weak self] in self?.overlay.setMode($0) ?? false }
        settings.onRecording = { [weak self] value in self?.recordingShortcut = value; _ = self?.registerHotKeys() }
        settings.onVisibilityChanged = { [weak self] _ in self?.overlay.presentationContextChanged(); _ = self?.registerHotKeys() }
        settings.updater = Updater.isAvailable ? updater : nil
    }
    @objc private func settingsAction() { openSettings() }
    private func openSettings(_ section: SettingsSection? = nil) {
        menuBar.close()
        settings.show(section)
        _ = registerHotKeys()
    }
    @objc private func quit() { NSApp.terminate(nil) }
    private func perform(_ action: PresentationAction) {
        if let tool = action.tool {
            if overlay.chooseTool(tool) { _ = overlay.activate() }
            return
        }
        switch action {
        case .mode: overlay.toggleMode()
        case .capture: overlay.captureScreenshot()
        case .magnifier: _ = overlay.setMagnification(!overlay.isMagnifying)
        case .toolbar: overlay.toggleToolbar()
        case .nextPointer: overlay.cyclePointer(by: 1)
        case .previousPointer: overlay.cyclePointer(by: -1)
        case .sound: overlay.soundOn.toggle()
        case .matchInk: Preferences.inkChoice = .match
        case .undo: overlay.undo()
        case .redo: overlay.redo()
        case .settings: openSettings()
        case .exitPointer: overlay.deactivate()
        default: break
        }
    }

    private func apply(_ value: Shortcut?, action: PresentationAction?, toggle: Bool) -> Bool {
        let previous = action.map { Preferences.shortcut(for: $0) } ?? (toggle ? Preferences.toggleShortcut : Preferences.clearShortcut)
        if let value {
            let other = [(Preferences.toggleShortcut, action == nil && toggle), (Preferences.clearShortcut, action == nil && !toggle)]
                + PresentationAction.allCases.map { (Preferences.shortcut(for: $0), action == $0) }
            guard !other.contains(where: { !$0.1 && $0.0?.keyCode == value.keyCode && $0.0?.modifiers == value.modifiers }) else {
                settings.shortcutError = "\(value.display) is already assigned. Clear that command or choose another shortcut."
                return false
            }
            guard !ShortcutRules.isReserved(value) else {
                settings.shortcutError = "\(value.display) is reserved for standard app commands. Choose another shortcut."
                return false
            }
            unregisterHotKeys()
            guard let probe = HotKeyCenter.shared.register(keyCode: value.keyCode, modifiers: value.modifiers, action: {}) else {
                settings.shortcutError = "\(value.display) is unavailable. Another app or macOS may be using it. Choose another shortcut."
                _ = registerHotKeys()
                return false
            }
            HotKeyCenter.shared.unregister(probe)
        }
        if let action { Preferences.setShortcut(value, for: action) }
        else if toggle { Preferences.toggleShortcut = value }
        else { Preferences.clearShortcut = value }
        guard registerHotKeys() else {
            if let action { Preferences.setShortcut(previous, for: action) }
            else if toggle { Preferences.toggleShortcut = previous }
            else { Preferences.clearShortcut = previous }
            _ = registerHotKeys()
            settings.shortcutError = "The shortcut could not be registered. The previous assignment was kept. Choose another shortcut."
            return false
        }
        settings.shortcutError = nil
        return true
    }
    // Available only through the control bridge's explicit test-mode operation.
    private func verifyShortcuts(_ request: [String: Any]) -> [String: Any] {
        guard let suite = ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"], !suite.isEmpty else {
            return ["accepted": false, "error": "Use an isolated defaults suite for shortcut verification."]
        }
        var accepted = true
        if let command = request["command"] as? String {
            if command == "reset" {
                Preferences.resetAll()
            } else {
                let action = PresentationAction(rawValue: command)
                guard command == "toggle" || command == "clear" || action != nil else { return ["accepted": false] }
                var shortcut: Shortcut?
                if let value = request["shortcut"] as? [String: Any] {
                    guard let code = value["keyCode"] as? Int, (0...127).contains(code),
                          let mods = value["modifiers"] as? Int, mods >= 0, mods <= Int(UInt32.max),
                          let display = value["display"] as? String, !display.isEmpty else { return ["accepted": false] }
                    shortcut = Shortcut(keyCode: UInt32(code), modifiers: UInt32(mods), display: display)
                } else if request["shortcut"] != nil && !(request["shortcut"] is NSNull) { return ["accepted": false] }
                accepted = apply(shortcut, action: action, toggle: command == "toggle")
            }
        }
        menuBar.refresh()
        return ["accepted": accepted, "defaultsSuite": suite, "assignments": Preferences.shortcutState,
                "registeredCount": hotKeys.count, "error": settings.shortcutError ?? "",
                "menu": menuBar.shortcutDiagnostics]
    }

    private func unregisterHotKeys() {
        overlay.cancelHandGestures(notify: false)
        hotKeys.forEach(HotKeyCenter.shared.unregister)
        hotKeys.removeAll()
        keySignature = ""
    }
    @discardableResult
    private func registerHotKeys() -> Bool {
        if recordingShortcut { unregisterHotKeys(); return true }
        var bindings: [(String, Shortcut, () -> Void, (() -> Void)?)] = []
        if let shortcut = Preferences.toggleShortcut {
            bindings.append(("toggle", shortcut, { [weak self] in self?.overlay.toggle() }, nil))
        }
        if let shortcut = Preferences.clearShortcut {
            bindings.append(("clear", shortcut, { [weak self] in self?.overlay.clearInk() }, nil))
        }
        if overlay.canUsePresentationShortcuts {
            for action in PresentationAction.allCases where !action.drawOnly || overlay.canUseDrawingShortcuts {
                if let shortcut = Preferences.shortcut(for: action) {
                    if let slot = action.gesture {
                        guard overlay.style.assetName != nil, HandGestureCatalog.image(slot, style: overlay.style) != nil else { continue }
                        bindings.append(("\(action.rawValue):\(overlay.style.rawValue)", shortcut,
                            { [weak self] in _ = self?.overlay.beginGesture(slot, owner: action.rawValue, shortcut: shortcut) },
                            { [weak self] in self?.overlay.endGesture(action.rawValue) }))
                    } else { bindings.append((action.rawValue, shortcut, { [weak self] in self?.perform(action) }, nil)) }
                }
            }
        }
        let signature = bindings.map { "\($0.0):\($0.1.keyCode):\($0.1.modifiers)" }.joined(separator: "|")
        if signature == keySignature { return true }
        unregisterHotKeys()
        for (_, shortcut, action, release) in bindings {
            guard let id = HotKeyCenter.shared.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, action: action, onRelease: release) else {
                unregisterHotKeys()
                settings.shortcutError = "\(shortcut.display) could not be registered. Another app or macOS may be using it. Review Shortcuts in Settings."
                Log.write("shortcut unavailable: \(shortcut.display)")
                return false
            }
            hotKeys.append(id)
        }
        keySignature = signature
        return true
    }

    private func editingMenu() -> NSMenu {
        let root = NSMenu()
        let app = NSMenuItem()
        let application = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(settingsAction), keyEquivalent: ",")
        settings.target = self
        application.addItem(settings)
        application.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        application.addItem(withTitle: "Quit Look Here Please", action: #selector(quit), keyEquivalent: "q").target = self
        app.submenu = application
        root.addItem(app)
        let edit = NSMenuItem()
        let editing = NSMenu(title: "Edit")
        editing.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editing.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editing.addItem(.separator())
        for (title, selector, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editing.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        edit.submenu = editing
        root.addItem(edit)
        return root
    }
}
