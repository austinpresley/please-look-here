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
    private let practice = GettingStartedPracticeWindow()
    private lazy var menuBar = MenuBarControls(overlay: overlay, perform: { [weak self] request in
        guard let self, let data = try? JSONSerialization.data(withJSONObject: request),
              let response = try? JSONSerialization.jsonObject(with: self.control.handle(data)) as? [String: Any] else { return "Action unavailable" }
        return response["ok"] as? Bool == true ? "" : ((response["error"] as? [String: Any])?["message"] as? String ?? "Action unavailable")
    }, checkForUpdates: { [weak self] in self?.updater.checkForUpdates() })
    private let hotKeys = HotKeyBindings()
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
        welcome.onPractice = { [weak self] in self?.openPractice() }
        menuBar.openPractice = { [weak self] in
            // Leave native menu tracking before presenting a key window.
            RunLoop.main.perform { [weak self] in self?.openPractice() }
        }
        practice.readiness = { [weak self] in
            PracticeReadiness(drawingAllowed: self?.overlay.drawingAllowed ?? false,
                              radialAssigned: Preferences.radialTrigger != nil, capturing: self?.overlay.isCapturing ?? false)
        }
        practice.openShortcut = { [weak self] target in
            guard let self else { return }
            self.menuBar.close()
            self.settings.showShortcut(target)
            _ = self.registerHotKeys()
        }
        practice.onVisibilityChanged = { [weak self] in
            self?.overlay.presentationContextChanged()
            _ = self?.registerHotKeys()
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
        settings.openPractice = { [weak self] in self?.openPractice($0) }
        settings.applyToggleShortcut = { [weak self] value in self?.apply(value, action: nil, toggle: true) ?? false }
        settings.applyClearShortcut = { [weak self] value in self?.apply(value, action: nil, toggle: false) ?? false }
        settings.applyPresentationShortcut = { [weak self] action, value in self?.apply(value, action: action, toggle: false) ?? false }
        settings.applyMode = { [weak self] in self?.overlay.setMode($0) ?? false }
        settings.onRecording = { [weak self] value in self?.recordingShortcut = value; _ = self?.registerHotKeys() }
        settings.onVisibilityChanged = { [weak self] _ in self?.overlay.presentationContextChanged(); _ = self?.registerHotKeys() }
        settings.updater = Updater.isAvailable ? updater : nil
    }
    private func openPractice(_ lesson: PracticeLesson = .pointer) {
        menuBar.close()
        practice.show(lesson)
        overlay.presentationContextChanged()
        _ = registerHotKeys()
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
        case .captureRegion: overlay.captureRegion()
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
        let command = action?.rawValue ?? (toggle ? "toggle" : "clear")
        let previous: Shortcut?
        if let action { previous = Preferences.shortcut(for: action) }
        else { previous = toggle ? Preferences.toggleShortcut : Preferences.clearShortcut }
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
            // Release only this command while validating its replacement.
            hotKeys.remove(command)
            guard let probe = HotKeyCenter.shared.register(keyCode: value.keyCode, modifiers: value.modifiers, action: {}) else {
                settings.shortcutError = "\(value.display) is unavailable. Another app or macOS may be using it. Choose another shortcut."
                _ = registerHotKeys()
                return false
            }
            HotKeyCenter.shared.unregister(probe)
        } else { hotKeys.remove(command) }
        if let action { Preferences.setShortcut(value, for: action) }
        else if toggle { Preferences.toggleShortcut = value }
        else { Preferences.clearShortcut = value }
        _ = registerHotKeys()
        guard hotKeys.failures[command] == nil else {
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
                "registeredCount": hotKeys.count, "conflicts": settings.shortcutConflicts, "error": settings.shortcutError ?? "",
                "menu": menuBar.shortcutDiagnostics]
    }

    private func unregisterHotKeys() {
        overlay.cancelHandGestures(notify: false)
        hotKeys.removeAll()
        publishShortcutConflicts()
    }
    @discardableResult
    private func registerHotKeys() -> Bool {
        if recordingShortcut {
            overlay.cancelHandGestures(notify: false)
            hotKeys.removeAll(preservingFailures: true)
            publishShortcutConflicts()
            return true
        }
        var bindings: [HotKeyBindings.Binding] = []
        if let shortcut = Preferences.toggleShortcut {
            bindings.append(.init("toggle", shortcut: shortcut, press: { [weak self] in self?.overlay.toggle() }))
        }
        if let shortcut = Preferences.clearShortcut {
            bindings.append(.init("clear", shortcut: shortcut, press: { [weak self] in self?.overlay.clearInk() }))
        }
        if overlay.canUsePresentationShortcuts {
            for action in PresentationAction.allCases where !action.drawOnly || overlay.canUseDrawingShortcuts {
                if let shortcut = Preferences.shortcut(for: action) {
                    if let slot = action.gesture {
                        guard overlay.style.assetName != nil, HandGestureCatalog.image(slot, style: overlay.style) != nil else { continue }
                        bindings.append(.init(action.rawValue, identity: "\(action.rawValue):\(overlay.style.rawValue)", shortcut: shortcut,
                            press: { [weak self] in _ = self?.overlay.beginGesture(slot, owner: action.rawValue, shortcut: shortcut) },
                            release: { [weak self] in self?.overlay.endGesture(action.rawValue) },
                            onRemove: { [weak self] in self?.overlay.endGesture(action.rawValue, notify: false) }))
                    } else { bindings.append(.init(action.rawValue, shortcut: shortcut, press: { [weak self] in self?.perform(action) })) }
                }
            }
        }
        let previousFailures = hotKeys.failures
        var assignments: [String: Shortcut] = [:]
        assignments["toggle"] = Preferences.toggleShortcut
        assignments["clear"] = Preferences.clearShortcut
        for action in PresentationAction.allCases { assignments[action.rawValue] = Preferences.shortcut(for: action) }
        let success = hotKeys.update(bindings, assignments: assignments)
        publishShortcutConflicts()
        for (command, shortcut) in hotKeys.failures where previousFailures[command] != shortcut {
            Log.write("shortcut unavailable: \(command) \(shortcut.display)")
        }
        return success
    }
    private func publishShortcutConflicts() {
        let conflicts = hotKeys.failures.mapValues { "\($0.display) is unavailable. Another app or macOS may be using it. Choose another shortcut." }
        settings.shortcutConflicts = conflicts
        menuBar.shortcutConflicts = conflicts
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
