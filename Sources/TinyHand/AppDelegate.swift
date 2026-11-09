import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let overlay = OverlayController()
    private let settings = SettingsWindow()
    private let updater = Updater()
    private let welcome = WelcomeWindow()
    private let menu = NSMenu()
    private var permissionItem: NSMenuItem?
    private var toggleItem: NSMenuItem?
    private var clearItem: NSMenuItem?
    private var undoItem: NSMenuItem?
    private var redoItem: NSMenuItem?
    private var soundItem: NSMenuItem?
    private var pointItem: NSMenuItem?
    private var drawItem: NSMenuItem?
    private var captureItem: NSMenuItem?
    private var actionItems: [PresentationAction: NSMenuItem] = [:]
    private var hotKeys: [UInt32] = []
    private var keySignature = ""
    private var recordingShortcut = false
    private var observer: Any?
    private lazy var control = ControlBridge(overlay: overlay, openSettings: { [weak self] section in self?.openSettings(section.flatMap(SettingsSection.init(rawValue:))) },
                                             openHandCreator: { [weak self] in self?.settings.showHandCreator() },
                                             snapshotSettings: { [weak self] in self?.settings.exportVerificationSnapshot(to: $0) ?? false })

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = editingMenu()
        HandAsset.preloadThumbnails(PointerStyle.allCases.compactMap(\.assetName))
        CursorHider.enableBackgroundHiding()
        overlay.onActiveChanged = { [weak self] in self?.updateIcon(); self?.refreshMenu(); _ = self?.registerHotKeys() }
        overlay.onSoundChanged = { [weak self] in self?.refreshMenu() }
        overlay.onShortcutContextChanged = { [weak self] in _ = self?.registerHotKeys() }
        overlay.extraPassThrough = { [weak self] in self?.statusItem?.button?.window.map { [$0.frame] } ?? [] }
        overlay.onNeedsPermission = { [weak self] in self?.welcome.show(forDrawing: true) }
        welcome.onTryIt = { [weak self] mode in
            guard let self = self, self.overlay.setMode(mode) else { return }
            _ = self.overlay.activate()
        }
        setupStatusItem()
        setupSettings()
        applyTheme()
        observer = NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [weak self] _ in
            self?.applyTheme()
            self?.refreshMenu()
            _ = self?.registerHotKeys()
        }
        _ = registerHotKeys()
        updater.start()
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

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        menu.autoenablesItems = false
        permissionItem = add("Allow Drawing…", #selector(showPermission))
        toggleItem = add("Turn Pointer On", #selector(toggle))
        menu.addItem(.separator())
        pointItem = add("Point", #selector(selectPoint))
        drawItem = add("Draw", #selector(selectDraw))
        for action in PresentationAction.allCases.filter(\.drawOnly) {
            let item = add(action.title, #selector(presentationAction(_:)))
            item.representedObject = action.rawValue
            actionItems[action] = item
        }
        undoItem = add("Undo Annotation", #selector(undo))
        redoItem = add("Redo Annotation", #selector(redo))
        clearItem = add("Clear Drawing", #selector(clearInk))
        captureItem = add("Take Screenshot", #selector(capture))
        menu.addItem(.separator())
        for action in PresentationAction.allCases.filter({ !$0.drawOnly && $0 != .capture && $0 != .mode }) {
            let item = add(action.title, #selector(presentationAction(_:)))
            item.representedObject = action.rawValue
            actionItems[action] = item
            if action == .sound { soundItem = item }
        }
        menu.addItem(.separator())
        let settingsItem = add("Settings…", #selector(settingsAction))
        settingsItem.keyEquivalent = ","
        settingsItem.keyEquivalentModifierMask = .command
        if Updater.isAvailable { _ = add("Check for Updates…", #selector(checkForUpdates)) }
        menu.addItem(.separator())
        let quit = add("Quit TinyHand", #selector(quit))
        quit.keyEquivalent = "q"; quit.keyEquivalentModifierMask = .command
        menu.delegate = self
        updateIcon()
        refreshMenu()
    }
    @discardableResult
    private func add(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }
    private func setupSettings() {
        settings.applyToggleShortcut = { [weak self] value in self?.apply(value, action: nil, toggle: true) ?? false }
        settings.applyClearShortcut = { [weak self] value in self?.apply(value, action: nil, toggle: false) ?? false }
        settings.applyPresentationShortcut = { [weak self] action, value in self?.apply(value, action: action, toggle: false) ?? false }
        settings.applyMode = { [weak self] in self?.overlay.setMode($0) ?? false }
        settings.onRecording = { [weak self] value in self?.recordingShortcut = value; _ = self?.registerHotKeys() }
        settings.onVisibilityChanged = { [weak self] _ in _ = self?.registerHotKeys() }
        settings.updater = Updater.isAvailable ? updater : nil
    }
    private func refreshMenu() {
        guard toggleItem != nil else { return }
        toggleItem?.title = overlay.isActive ? "Turn Pointer Off" : "Turn Pointer On"
        setShortcut(Preferences.toggleShortcut, on: toggleItem)
        setShortcut(Preferences.clearShortcut, on: clearItem)
        setShortcut(Preferences.shortcut(for: .capture), on: captureItem)
        setShortcut(Shortcut(keyCode: UInt32(kVK_ANSI_Z), modifiers: UInt32(cmdKey), display: "⌘Z"), on: undoItem)
        setShortcut(Shortcut(keyCode: UInt32(kVK_ANSI_Z), modifiers: UInt32(cmdKey | shiftKey), display: "⇧⌘Z"), on: redoItem)
        permissionItem?.isHidden = AXIsProcessTrusted()
        pointItem?.state = overlay.mode == .point ? .on : .off
        drawItem?.state = overlay.mode == .draw ? .on : .off
        undoItem?.isEnabled = overlay.canUndo
        redoItem?.isEnabled = overlay.canRedo
        clearItem?.isEnabled = overlay.inkStrokes > 0
        captureItem?.isEnabled = !overlay.isCapturing
        for (action, item) in actionItems {
            setShortcut(Preferences.shortcut(for: action), on: item)
            if let tool = action.tool { item.state = Preferences.drawingTool == tool && overlay.mode == .draw ? .on : .off }
        }
        actionItems[.toolbar]?.title = Preferences.showToolbar ? "Hide Toolbar" : "Show Toolbar"
        soundItem?.state = overlay.soundOn ? .on : .off
    }

    @objc private func statusClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            refreshMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else { overlay.toggle() }
    }
    func menuWillOpen(_ menu: NSMenu) { overlay.suspendInput(true); refreshMenu() }
    func menuDidClose(_ menu: NSMenu) { overlay.suspendInput(false) }
    @objc private func toggle() { overlay.toggle() }
    @objc private func selectPoint() { if overlay.setMode(.point) { _ = overlay.activate() } }
    @objc private func selectDraw() { if overlay.setMode(.draw) { _ = overlay.activate() } }
    @objc private func clearInk() { overlay.clearInk() }
    @objc private func undo() { overlay.undo() }
    @objc private func redo() { overlay.redo() }
    @objc private func capture() { overlay.captureScreenshot() }
    @objc private func showPermission() { welcome.show(forDrawing: true) }
    @objc private func settingsAction() { openSettings() }
    private func openSettings(_ section: SettingsSection? = nil) { settings.show(section); _ = registerHotKeys() }
    @objc private func checkForUpdates() { updater.checkForUpdates() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func presentationAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = PresentationAction(rawValue: raw) else { return }
        perform(action)
    }
    private func perform(_ action: PresentationAction) {
        if let tool = action.tool {
            if overlay.chooseTool(tool) { _ = overlay.activate() }
            return
        }
        switch action {
        case .mode: overlay.toggleMode()
        case .capture: overlay.captureScreenshot()
        case .toolbar: overlay.toggleToolbar()
        case .nextPointer: overlay.cyclePointer(by: 1)
        case .previousPointer: overlay.cyclePointer(by: -1)
        case .sound: overlay.soundOn.toggle()
        case .matchInk: Preferences.inkChoice = .match
        default: break
        }
    }

    private func apply(_ value: Shortcut, action: PresentationAction?, toggle: Bool) -> Bool {
        let other = [(Preferences.toggleShortcut, action == nil && toggle), (Preferences.clearShortcut, action == nil && !toggle)]
            + PresentationAction.allCases.map { (Preferences.shortcut(for: $0), action == $0) }
        guard !other.contains(where: { !$0.1 && $0.0.keyCode == value.keyCode && $0.0.modifiers == value.modifiers }) else { return false }
        guard !ShortcutRules.isReserved(value) else { return false }
        unregisterHotKeys()
        guard let probe = HotKeyCenter.shared.register(keyCode: value.keyCode, modifiers: value.modifiers, action: {}) else { _ = registerHotKeys(); return false }
        HotKeyCenter.shared.unregister(probe)
        if let action = action { Preferences.setShortcut(value, for: action) }
        else if toggle { Preferences.toggleShortcut = value }
        else { Preferences.clearShortcut = value }
        _ = registerHotKeys()
        return true
    }
    private func unregisterHotKeys() {
        hotKeys.forEach(HotKeyCenter.shared.unregister)
        hotKeys.removeAll()
        keySignature = ""
    }
    @discardableResult
    private func registerHotKeys() -> Bool {
        if recordingShortcut { unregisterHotKeys(); return true }
        var bindings: [(Shortcut, () -> Void)] = [
            (Preferences.toggleShortcut, { [weak self] in self?.overlay.toggle() }),
            (Preferences.clearShortcut, { [weak self] in self?.overlay.clearInk() })
        ]
        if overlay.canUsePresentationShortcuts {
            for action in PresentationAction.allCases where !action.drawOnly || overlay.canUseDrawingShortcuts {
                bindings.append((Preferences.shortcut(for: action), { [weak self] in self?.perform(action) }))
            }
        }
        if overlay.canUseDrawingShortcuts {
            bindings += [
                (Shortcut(keyCode: UInt32(kVK_ANSI_Z), modifiers: UInt32(cmdKey), display: "⌘Z"), { [weak self] in self?.overlay.undo() }),
                (Shortcut(keyCode: UInt32(kVK_ANSI_Z), modifiers: UInt32(cmdKey | shiftKey), display: "⇧⌘Z"), { [weak self] in self?.overlay.redo() }),
                (Shortcut(keyCode: UInt32(kVK_ANSI_Comma), modifiers: UInt32(cmdKey), display: "⌘,"), { [weak self] in self?.openSettings() })
            ]
        }
        let signature = bindings.map { "\($0.0.keyCode):\($0.0.modifiers)" }.joined(separator: "|")
        if signature == keySignature { return true }
        unregisterHotKeys()
        for (shortcut, action) in bindings {
            guard let id = HotKeyCenter.shared.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, action: action) else {
                unregisterHotKeys()
                Log.write("shortcut unavailable: \(shortcut.display)")
                return false
            }
            hotKeys.append(id)
        }
        keySignature = signature
        return true
    }

    private func updateIcon() {
        guard statusItem != nil else { return }
        let on = overlay.isActive
        let image = Bundle.main.image(forResource: on ? "menubar_on" : "menubar_off")
            ?? NSImage(systemSymbolName: on ? "hand.point.up.left.fill" : "hand.point.up.left", accessibilityDescription: "TinyHand")
        image?.size = CGSize(width: 18, height: 18)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = on ? "TinyHand \(overlay.mode.title) · click to turn off, right-click for controls" : "TinyHand · click to turn on, right-click for controls"
    }
    private func setShortcut(_ shortcut: Shortcut, on item: NSMenuItem?) {
        let tail = shortcut.display.filter { !"⌃⌥⇧⌘".contains($0) }
        let special: [UInt32: String] = [UInt32(kVK_LeftArrow): String(UnicodeScalar(0xF702)!),
                                        UInt32(kVK_RightArrow): String(UnicodeScalar(0xF703)!)]
        item?.keyEquivalent = special[shortcut.keyCode] ?? tail.lowercased()
        var flags: NSEvent.ModifierFlags = []
        if shortcut.modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if shortcut.modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if shortcut.modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if shortcut.modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        item?.keyEquivalentModifierMask = flags
    }

    private func editingMenu() -> NSMenu {
        let root = NSMenu()
        let app = NSMenuItem()
        let application = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(settingsAction), keyEquivalent: ",")
        settings.target = self
        application.addItem(settings)
        application.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        application.addItem(withTitle: "Quit TinyHand", action: #selector(quit), keyEquivalent: "q").target = self
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
