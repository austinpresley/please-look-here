import AppKit
import Carbon.HIToolbox
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
    var applyMode: ((PointerMode) -> Bool)? {
        didSet { model.applyMode = applyMode }
    }
    var onVisibilityChanged: ((Bool) -> Void)?
    private var permissionTimer: Timer?
    var updater: Updater? {
        didSet { model.updater = updater }
    }

    private var window: NSWindow?
    private let model = SettingsModel()

    override init() {
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
        w.setContentSize(CGSize(width: 784, height: target))
        let x = min(max(w.frame.minX, visible.minX + 8), max(visible.minX + 8, visible.maxX - w.frame.width - 8))
        let y = min(max(top - w.frame.height, visible.minY + 8), max(visible.minY + 8, visible.maxY - w.frame.height - 8))
        w.setFrameOrigin(CGPoint(x: x, y: y))
    }

    func show(_ section: SettingsSection? = nil) {
        if window == nil {
            build()
        }
        if let section = section {
            model.section = section
        }
        model.shortcutError = nil
        model.pinMessage = nil
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible != true {
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(nil)
        onVisibilityChanged?(true)
        permissionTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.model.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    func showHandCreator() {
        show(.pointers)
        model.startMakingHand()
    }

    func snapshot(_ section: SettingsSection = .general, dark: Bool = false) -> CGImage? {
        if window == nil {
            build()
        }
        guard let w = window else {
            return nil
        }
        GridProbes.shared.probes.removeAll()
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

    func exportVerificationSnapshot(to path: String) -> Bool {
        guard let w = window, w.isVisible, w.isKeyWindow, NSApp.isActive,
              let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(w.windowNumber), [.boundsIgnoreFraming, .bestResolution]),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return false }
        do {
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
            GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: w.frame.size)
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
        let host = NSHostingView(rootView: SettingsView(model: model))
        host.focusRingType = .none
        w.contentView = host
        window = w
    }

    func windowWillClose(_ notification: Notification) {
        permissionTimer?.invalidate()
        permissionTimer = nil
        onRecording?(false)
        onVisibilityChanged?(false)
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

    init(shortcut: Shortcut?) {
        self.shortcut = shortcut
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryChange)
        focusRingType = .none
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
            keys.addArrangedSubview(ShortcutRecorder.text(text))
            return
        }
        if !tail.isEmpty {
            caps.append(tail)
        }
        for cap in caps {
            keys.addArrangedSubview(ShortcutRecorder.keycap(cap))
        }
    }

    private static func text(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: 12, weight: .medium)
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
                layer?.shadowOffset = CGSize(width: 0, height: -1)
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
        setLabel("Press keys", dim: true)
        setRecordingLook(true)
        onRecording?(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else {
                return event
            }
            if event.type == .flagsChanged {
                let flags = event.modifierFlags.intersection([.control, .option, .command, .shift])
                if flags.isEmpty {
                    self.setLabel("Press keys", dim: true)
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
