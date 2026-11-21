import AppKit
import Carbon.HIToolbox
import ApplicationServices
import SwiftUI

final class SettingsWindow: NSObject, NSWindowDelegate {
    var applyToggleShortcut: ((Shortcut?) -> Bool)? {
        didSet { model.applyToggleShortcut = applyToggleShortcut }
    }
    var applyClearShortcut: ((Shortcut?) -> Bool)? {
        didSet { model.applyClearShortcut = applyClearShortcut }
    }
    var onRecording: ((Bool) -> Void)? {
        didSet { model.onRecording = onRecording }
    }
    var applyPresentationShortcut: ((PresentationAction, Shortcut?) -> Bool)? {
        didSet { model.applyPresentationShortcut = applyPresentationShortcut }
    }
    var shortcutError: String? {
        get { model.shortcutError }
        set { model.shortcutError = newValue }
    }
    var shortcutConflicts: [String: String] {
        get { model.shortcutConflicts }
        set { model.shortcutConflicts = newValue }
    }
    var applyMode: ((PointerMode) -> Bool)? {
        didSet { model.applyMode = applyMode }
    }
    var onVisibilityChanged: ((Bool) -> Void)?
    var editQuickControlFavorites: (() -> Void)? {
        didSet { model.editQuickControlFavorites = editQuickControlFavorites }
    }
    var openPractice: ((PracticeLesson) -> Void)? {
        didSet { model.openPractice = openPractice }
    }
    private var permissionTimer: Timer?
    private var permissionState: (Bool, Bool)?
    var updater: Updater? {
        didSet { model.updater = updater }
    }

    private(set) var window: NSWindow?
    private let focusDriver: QuickControlsFocus
    private var focusRestoration: QuickControlsFocusRestoration?
    private let model = SettingsModel()
    func chooseCaptureFolder() { model.chooseCaptureFolder() }

    init(focus: QuickControlsFocus = .system) {
        focusDriver = focus
        super.init()
        model.onContentHeightChanged = { [weak self] height in
            DispatchQueue.main.async { self?.fitHeight(height) }
        }
    }

    private func fitHeight(_ height: CGFloat) {
        guard height > 0, ProcessInfo.processInfo.environment["TH_SETTINGS_HEIGHT"] == nil, let w = window else { return }
        let visible = (w.screen ?? NSScreen.main)?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1200, height: 900)
        let maximum = visible.height
        let target = min(maximum - 64, max(440, (height / 4).rounded(.up) * 4))
        guard abs((w.contentView?.bounds.height ?? 0) - target) > 2 else { return }
        let top = w.frame.maxY
        w.setContentSize(CGSize(width: max(784, w.contentView?.bounds.width ?? 784), height: target))
        let x = min(max(w.frame.minX, visible.minX + 8), max(visible.minX + 8, visible.maxX - w.frame.width - 8))
        let y = min(max(top - w.frame.height, visible.minY + 8), max(visible.minY + 8, visible.maxY - w.frame.height - 8))
        w.setFrameOrigin(CGPoint(x: x, y: y))
    }

    func show(_ section: SettingsSection? = nil, restoration: QuickControlsFocusRestoration? = nil) {
        if focusRestoration == nil { focusRestoration = restoration }
        if window == nil {
            build()
        }
        model.cancelShortcutNavigation()
        if let section = section {
            model.section = section
        }
        if let window, model.section == .pointers, window.contentView!.bounds.width < 1040 {
            window.setContentSize(CGSize(width: 1040, height: max(720, window.contentView!.bounds.height)))
        }
        window?.minSize = CGSize(width: model.section == .pointers ? 1040 : 784, height: 440)
        if model.section == .shortcuts { model.resetShortcutSections() }
        model.shortcutError = nil
        model.pinMessage = nil
        if window?.isVisible != true {
            window?.center()
        }
        if let window, !focusDriver.focus(window, nil, true) { restoreFocus() }
        onVisibilityChanged?(true)
        permissionTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let current = (AXIsProcessTrusted(), ScreenCapture.hasPermission)
            if self.permissionState?.0 != current.0 || self.permissionState?.1 != current.1 {
                self.permissionState = current
                self.model.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    func showHandCreator() {
        show(.pointers)
        model.startMakingHand()
    }

    func showRoute(_ name: String?) {
        let route = name.flatMap(SettingsRoute.parse)
        show(route?.section)
        if let route { model.navigate(route) }
    }

    func showShortcut(_ target: PracticeShortcutTarget) {
        show(.shortcuts)
        model.focusShortcut(target)
    }

    func snapshot(_ section: SettingsSection = .general, dark: Bool = false) -> CGImage? {
        if window == nil {
            build()
        }
        guard let w = window else {
            return nil
        }
        GridProbes.shared.probes.removeAll()
        model.cancelShortcutNavigation()
        model.section = section
        let env = ProcessInfo.processInfo.environment
        if env["TH_MAKE_HAND"] != nil {
            model.makingHand = true
            model.handIdea = env["TH_MAKE_HAND"] ?? ""
        }
        if let draft = env["TH_DRAFT"] {
            model.loadDraft(URL(fileURLWithPath: draft))
        }
        w.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        if let tall = ProcessInfo.processInfo.environment["TH_SETTINGS_HEIGHT"].flatMap(Double.init) {
            w.setContentSize(NSSize(width: 780, height: tall))
        }
        w.center()
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        w.makeFirstResponder(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(ProcessInfo.processInfo.environment["TH_SETTINGS_HEIGHT"] == nil ? 0.8 : 4))
        let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(w.windowNumber), [.boundsIgnoreFraming, .bestResolution])
        print("SNAPSHOT section=\(section.rawValue) dark=\(dark) key=\(w.isKeyWindow) size=\(Int(w.frame.width))x\(Int(w.frame.height))")
        w.orderOut(nil)
        return image
    }

    var snapshotSize: CGSize { window?.frame.size ?? .zero }

    /// Local model/control actions guarded by the bridge's disposable Settings
    /// suite. No native events, desktop capture or real preferences.
    func verify(_ request: [String: Any]) throws -> [String: Any] {
        switch request["action"] as? String ?? "status" {
        case "status": break
        case "about": model.showingAbout = request["expanded"] as? Bool ?? false
        case "scroll": model.scrollToBottom = request["bottom"] as? Bool ?? false
        case "collapse": show(.shortcuts)
        case "expand":
            guard let raw = request["groups"] as? [String], raw.allSatisfy({ ShortcutSettingsGroup(rawValue: $0) != nil }) else {
                throw ControlBridge.Problem(code: "invalid-request", message: "Choose valid shortcut groups")
            }
            show(.shortcuts)
            for value in raw { model.shortcutDisclosure.set(ShortcutSettingsGroup(rawValue: value)!, expanded: true) }
        case "focus":
            guard let command = request["command"] as? String,
                  ["toggle", "clear", "radial"].contains(command) || PresentationAction(rawValue: command) != nil else {
                throw ControlBridge.Problem(code: "invalid-request", message: "Choose a known shortcut command")
            }
            show(.shortcuts); model.focusShortcut(command: command)
        case "record", "cancel-recording":
            guard let command = request["command"] as? String, let root = window?.contentView,
                  let recorder = ShortcutNavigation.control(identifier: "settings.shortcut.\(command)", in: root) as? ShortcutRecorder else {
                throw ControlBridge.Problem(code: "invalid-request", message: "Reveal and focus a mounted recorder first")
            }
            if request["action"] as? String == "record" { recorder.performClick(nil) }
            else { recorder.cancelRecording() }
        case "suggest-add": model.addSuggestedShortcuts()
        case "suggest-undo": model.undoSuggestedShortcuts()
        case "drawing-options": model.drawingAdvanced = request["advanced"] as? Bool ?? false
        case "replay-drawing":
            func replay(_ view: NSView) {
                if let canvas = view as? DrawingPracticeView { canvas.replaySample() }
                view.subviews.forEach(replay)
            }
            if let root = window?.contentView { replay(root) }
        case "gesture-preview":
            guard let raw = request["slot"] as? String, let slot = HandGestureSlot(rawValue: raw) else {
                throw ControlBridge.Problem(code: "invalid-request", message: "Choose first or second gesture")
            }
            func preview(_ view: NSView) {
                if let canvas = view as? PointerPreviewView { _ = canvas.arm.setGesture(slot); canvas.needsLayout = true }
                view.subviews.forEach(preview)
            }
            if let root = window?.contentView { preview(root) }
        case "preset-view":
            model.presetsModel.refresh()
            model.presetsModel.included = request["included"] as? Bool ?? false
            model.presetsModel.showingRecovery = request["recovery"] as? Bool ?? false
        case "import-review":
            let store = PresentationStore(directory: CustomHands.directory, storage: Preferences.storage)
            var archive = try store.captureArchive(); archive.setup.settings["strokeWidth"] = .number(10)
            model.presetsModel.importDetails = request["details"] as? Bool ?? false
            model.presetsModel.importFilename = "Workshop Backup.json"
            model.presetsModel.importPlan = try store.preview(archive)
        case "restore-review":
            if let copy = model.presetsModel.recoveryCopies.first { model.presetsModel.reviewRestore(copy) }
        case "dismiss-review": model.presetsModel.importPlan = nil; model.presetsModel.restorePlan = nil
        case "customize":
            guard let id = request["pointer"] as? String, let style = PointerStyle(rawValue: id) else {
                throw ControlBridge.Problem(code: "invalid-request", message: "Choose an available pointer")
            }
            show(.pointers); model.inspectPointer(style)
        case "inspector":
            show(.pointers)
            if let id = request["pointer"] as? String, let style = PointerStyle(rawValue: id) { model.inspectPointer(style) }
            if let scope = request["scope"] as? String, let value = PointerInspectorState.Scope(rawValue: scope) { model.pointerInspector.scope = value }
            if let filter = request["filter"] as? String, let value = PointerLibraryFilter.Category(rawValue: filter) { model.libraryFilter.category = value }
            if let query = request["query"] as? String { model.libraryFilter.query = query }
        case "new-hand": showHandCreator()
        case "save-preset":
            guard let name = request["name"] as? String, !name.isEmpty else {
                throw ControlBridge.Problem(code: "invalid-request", message: "Choose a preset name")
            }
            let presets = PresetsSettingsModel(); presets.name = name; presets.save()
            guard presets.presets.contains(where: { $0.name == name }) else {
                throw ControlBridge.Problem(code: "invalid-request", message: presets.message ?? "Unable to save test preset")
            }
        case "dismiss": model.makingHand = false
        default: throw ControlBridge.Problem(code: "invalid-request", message: "Unknown Settings test action")
        }
        window?.contentView?.layoutSubtreeIfNeeded()
        func controls(_ root: NSView) -> [String] {
            let own = (root as? NSControl)?.identifier?.rawValue
            return (own?.hasPrefix("settings.shortcut.") == true ? [own!] : []) + root.subviews.flatMap(controls)
        }
        return ["section": model.section.rawValue, "toolPane": model.toolsPane.rawValue,
                "expanded": model.shortcutDisclosure.expanded.map(\.rawValue).sorted(),
                "shortcutControls": window?.contentView.map(controls) ?? [],
                "windowID": (window?.attachedSheet ?? window).map { Int($0.windowNumber) } ?? 0,
                "inspectorScope": model.pointerInspector.scope.rawValue,
                "inspectorPointer": model.pointerInspector.style.rawValue,
                "inspectorHandControls": model.pointerInspector.handControls,
                "suggestedResult": model.suggestedResult?.summary ?? "",
                "suggestedAddCount": model.suggestedRows.filter { $0.status == .willAdd }.count,
                "presetNowCount": model.presetsModel.presets.filter { model.presetsModel.isCurrent($0) }.count,
                "recoveryCount": model.presetsModel.recoveryCopies.count,
                "sheet": model.makingHand ? "new-hand" : model.presetsModel.importPlan != nil ? "import" : model.presetsModel.restorePlan != nil ? "restore" : "none"]
    }

    func exportVerificationSnapshot(to path: String) -> Bool {
        guard let parent = window, let w = parent.attachedSheet ?? window, w.isVisible, w.isKeyWindow, NSApp.isActive,
              let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(w.windowNumber), [.boundsIgnoreFraming, .bestResolution]),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return false }
        do {
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
            let all = GridProbes.shared.probes
            if w !== parent {
                GridProbes.shared.probes = all.filter { $0.value.area.hasPrefix("pointer.customize") || $0.value.area.hasPrefix("pointer.newHand") || $0.value.area.hasPrefix("presets.import") }
            }
            GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: w.frame.size)
            GridProbes.shared.probes = all
            return true
        } catch { Log.write("verification snapshot failed: \(error)"); return false }
    }

    private func build() {
        let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 784, height: 640),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.title = "Look Here Please Settings"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        w.minSize = CGSize(width: 784, height: 440)
        w.delegate = self
        let host = SettingsHostingView(model: model)
        model.onShortcutNavigationLayout = { [weak host] in host?.scheduleShortcutNavigation() }
        host.focusRingType = .none
        w.contentView = host
        window = w
    }

    func windowWillClose(_ notification: Notification) {
        func stopRecorders(_ view: NSView) {
            if let recorder = view as? ShortcutRecorder, recorder.isRecording { recorder.cancelRecording() }
            view.subviews.forEach(stopRecorders)
        }
        if let content = window?.contentView { stopRecorders(content) }
        model.cancelShortcutNavigation()
        permissionTimer?.invalidate()
        permissionTimer = nil
        onRecording?(false)
        onVisibilityChanged?(false)
        restoreFocus()
    }

    private func restoreFocus() {
        let restoration = focusRestoration; focusRestoration = nil
        restoration?.restore()
    }

    func windowDidResignKey(_ notification: Notification) { model.cancelShortcutNavigation() }

    func windowDidBecomeKey(_ notification: Notification) { model.refresh() }

    func windowDidResize(_ notification: Notification) {
        (window?.contentView as? SettingsHostingView)?.scheduleShortcutNavigation(revealFocused: true)
    }
}

final class ShortcutRecorder: NSButton {
    var allowsPlainKeys = false
    var onChange: ((Shortcut?) -> Bool)?
    var onRecording: ((Bool) -> Void)?

    private var shortcut: Shortcut?
    private var monitor: Any?
    private var clickMonitor: Any?
    private let keys = NSStackView()

    init(shortcut: Shortcut?, command: String? = nil) {
        self.shortcut = shortcut
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryChange)
        focusRingType = .exterior
        setNavigationCommand(command)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
        toolTip = "Click, then press the new shortcut. Esc cancels."
        target = self
        action = #selector(startRecording)
        title = ""
        widthAnchor.constraint(equalToConstant: 132).isActive = true
        heightAnchor.constraint(equalToConstant: 30).isActive = true
        keys.orientation = .horizontal
        keys.spacing = 4
        keys.translatesAutoresizingMaskIntoConstraints = false
        addSubview(keys)
        NSLayoutConstraint.activate([
            keys.centerXAnchor.constraint(equalTo: centerXAnchor),
            keys.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setLabel(shortcut?.display ?? "Unassigned")
    }

    override var acceptsFirstResponder: Bool { true }

    override var focusRingMaskBounds: NSRect { bounds }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
    }

    func setNavigationCommand(_ command: String?) {
        let value = command.map { "settings.shortcut.\($0)" }
        identifier = value.map { NSUserInterfaceItemIdentifier($0) }
        setAccessibilityIdentifier(value)
    }

    var isRecording: Bool { monitor != nil }
    func cancelRecording() { stopRecording() }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
    }

    func show(_ s: Shortcut?) {
        guard monitor == nil, s != shortcut else {
            return
        }
        shortcut = s
        setLabel(s?.display ?? "Unassigned")
    }

    private static let modifierSymbols: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]

    private func setLabel(_ text: String, dim: Bool = false) {
        setAccessibilityValue(text)
        keys.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var rest = Substring(text)
        var caps: [String] = []
        while let c = rest.first, ShortcutRecorder.modifierSymbols.contains(c) {
            caps.append(String(c))
            rest = rest.dropFirst()
        }
        let tail = String(rest)
        if dim || (caps.isEmpty && tail.count > 4) {
            keys.addArrangedSubview(ShortcutRecorder.text(text, size: dim ? 11 : 12))
            return
        }
        if !tail.isEmpty {
            caps.append(tail)
        }
        for cap in caps {
            keys.addArrangedSubview(ShortcutRecorder.keycap(cap))
        }
    }

    private static func text(_ string: String, size: CGFloat = 12) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: size, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func keycap(_ key: String) -> NSView {
        let label = NSTextField(labelWithString: key)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        let cap = KeyCap()
        cap.addSubview(label)
        cap.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cap.heightAnchor.constraint(equalToConstant: 20),
            cap.widthAnchor.constraint(greaterThanOrEqualToConstant: 22),
            label.centerYAnchor.constraint(equalTo: cap.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: cap.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: cap.trailingAnchor, constant: -6),
        ])
        return cap
    }

    private final class KeyCap: NSView {
        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.cornerRadius = 5
            layer?.borderWidth = 0.5
            refresh()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) not used")
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            refresh()
        }

        private func refresh() {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.1).cgColor
                layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.18).cgColor
                layer?.shadowColor = NSColor.black.cgColor
                layer?.shadowOpacity = 0.15
                layer?.shadowRadius = 0
                layer?.shadowOffset = CGSize(width: 0, height: -1) // grid: ok optical keycap shadow, not layout spacing
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }

    private func setRecordingLook(_ on: Bool) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(on ? 0.09 : 0.05).cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        setRecordingLook(monitor != nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not used")
    }

    @objc private func startRecording() {
        guard monitor == nil else {
            return
        }
        setLabel("Press keys; Esc cancels", dim: true)
        setRecordingLook(true)
        onRecording?(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else {
                return event
            }
            if event.type == .flagsChanged {
                let flags = event.modifierFlags.intersection([.control, .option, .command, .shift])
                if flags.isEmpty {
                    self.setLabel("Press keys; Esc cancels", dim: true)
                } else {
                    self.setLabel(ShortcutRecorder.symbols(flags))
                }
                return nil
            }
            self.handle(event)
            return nil
        }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else {
                return event
            }
            let p = self.convert(event.locationInWindow, from: nil)
            if event.window != self.window || !self.bounds.contains(p) {
                self.stopRecording()
            }
            return event
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
        }
        if let m = clickMonitor {
            NSEvent.removeMonitor(m)
        }
        monitor = nil
        clickMonitor = nil
        setRecordingLook(false)
        setLabel(shortcut?.display ?? "Unassigned")
        onRecording?(false)
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }
        let flags = event.modifierFlags.intersection([.control, .option, .command, .shift])
        guard !flags.intersection([.control, .option, .command]).isEmpty || (allowsPlainKeys && event.charactersIgnoringModifiers?.rangeOfCharacter(from: .letters) != nil) else {
            setLabel("Add ⌃, ⌥ or ⌘", dim: true)
            return
        }
        let s = Shortcut(keyCode: UInt32(event.keyCode), modifiers: ShortcutRecorder.carbon(flags),
                         display: ShortcutRecorder.symbols(flags) + ShortcutRecorder.keyName(event))
        if onChange?(s) == true {
            shortcut = s
        }
        stopRecording()
    }

    private static func carbon(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m = 0
        if flags.contains(.control) { m |= controlKey }
        if flags.contains(.option) { m |= optionKey }
        if flags.contains(.shift) { m |= shiftKey }
        if flags.contains(.command) { m |= cmdKey }
        return UInt32(m)
    }

    private static func symbols(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    private static let special: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func keyName(_ event: NSEvent) -> String {
        if let name = special[Int(event.keyCode)] {
            return name
        }
        return (event.charactersIgnoringModifiers ?? "?").uppercased()
    }
}
