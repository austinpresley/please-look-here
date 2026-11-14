import AppKit

final class Toolbar: NSObject, NSWindowDelegate {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
    private final class Button: NSButton {
        var selected = false { didSet { refresh() } }
        private var hovering = false
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        }
        override func mouseEntered(with event: NSEvent) { hovering = true; refresh() }
        override func mouseExited(with event: NSEvent) { hovering = false; refresh() }
        override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); refresh() }
        private func refresh() {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(selected ? 0.16 : hovering ? 0.08 : 0).cgColor
            }
            setAccessibilityValue(selected ? "Selected" : "")
        }
    }
    private final class DragHandle: NSView {
        var moved: (() -> Void)?
        var started: (() -> Void)?
        var reset: (() -> Void)?
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { started?(); window?.performDrag(with: event); moved?() }
        override func rightMouseDown(with event: NSEvent) { reset?() }
        override func draw(_ dirtyRect: NSRect) {
            NSColor.secondaryLabelColor.setFill()
            for x: CGFloat in [6, 10] {
                for y: CGFloat in [10, 14, 18, 22] {
                    NSBezierPath(ovalIn: CGRect(x: x, y: y, width: 2, height: 2)).fill()
                }
            }
        }
    }

    var onPick: ((PointerStyle) -> Void)?
    var onMode: ((PointerMode) -> Void)?
    var onTool: ((DrawingTool) -> Void)?
    var onUndo: (() -> Void)?
    var onClear: (() -> Void)?
    var onCapture: (() -> Void)?
    var onMagnifier: (() -> Void)?
    var onToggleSound: (() -> Void)?
    var onExit: (() -> Void)?
    var onFixPermission: (() -> Void)?
    private let panel = Panel(contentRect: CGRect(x: 0, y: 0, width: 640, height: 48),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let root = NSStackView()
    private let row = NSStackView()
    private let tools = NSStackView()
    private let pointerStrip = NSStackView()
    private let interact = NSSwitch()
    private var toolButtons: [DrawingTool: Button] = [:]
    private var styleButtons: [PointerStyle: Button] = [:]
    private var colors: [InkChoice: Button] = [:]
    private var actions: [Button: () -> Void] = [:]
    private var shownStyles: [PointerStyle] = []
    private var current: PointerStyle?
    private var undoButton: Button!
    private var captureButton: Button!
    private var magnifierButton: Button!
    private var clearButton: Button!
    private var exitButton: Button!
    private var soundButton: Button!
    private var permissionButton: NSButton!
    private var hint: Panel?
    private var hintWork: DispatchWorkItem?
    private var screen: NSScreen?
    private var remembersMoves = false
    private var savingPosition = false
    private var previousPreferencePosition = Preferences.toolbarPosition
    var revealed: Bool { panel.isVisible && panel.alphaValue > 0 }
    var frame: CGRect { panel.frame }
    var windows: [NSWindow] { [panel] + (hint.map { [$0] } ?? []) }

    override init() {
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 4)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        let background = Self.surface()
        panel.contentView = background
        let container = Self.container(in: background)
        root.orientation = .vertical
        root.alignment = .centerX
        root.spacing = 8
        root.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        root.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            root.topAnchor.constraint(equalTo: container.topAnchor),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        for stack in [row, tools, pointerStrip] { stack.orientation = .horizontal; stack.spacing = 4; stack.alignment = .centerY }
        root.addArrangedSubview(row)
        root.addArrangedSubview(tools)
        let handle = DragHandle(frame: .zero)
        handle.widthAnchor.constraint(equalToConstant: 20).isActive = true
        handle.heightAnchor.constraint(equalToConstant: 32).isActive = true
        handle.toolTip = "Drag to move the toolbar. Right-click to reset its position."
        handle.setAccessibilityLabel("Move toolbar")
        handle.moved = { [weak self] in self?.savePosition() }
        handle.started = { [weak self] in
            self?.remembersMoves = true
        }
        handle.reset = { [weak self] in self?.resetPosition() }
        row.addArrangedSubview(handle)
        let interactLabel = NSTextField(labelWithString: "Interact")
        interactLabel.font = .systemFont(ofSize: 13)
        interact.state = Preferences.pointerMode.isInteractive ? .on : .off
        interact.target = self
        interact.action = #selector(modeChanged)
        interact.setAccessibilityLabel("Interact")
        interact.toolTip = Preferences.shortcut(for: .mode).help("On: use apps normally. Off: draw on screen.")
        let interaction = NSStackView(views: [interactLabel, interact])
        interaction.orientation = .horizontal
        interaction.alignment = .centerY
        interaction.spacing = 8
        row.addArrangedSubview(interaction)
        row.addArrangedSubview(Self.divider())
        row.addArrangedSubview(pointerStrip)
        row.addArrangedSubview(Self.divider())
        undoButton = button(symbol: "arrow.uturn.backward", tip: Preferences.shortcut(for: .undo).help("Undo annotation")) { [weak self] in self?.onUndo?() }
        captureButton = button(symbol: "camera", tip: Preferences.shortcut(for: .capture).help("Take Screenshot")) { [weak self] in self?.onCapture?() }
        magnifierButton = button(symbol: "plus.magnifyingglass", tip: Preferences.shortcut(for: .magnifier).help("Toggle Magnification")) { [weak self] in self?.onMagnifier?() }
        soundButton = button(symbol: "speaker.wave.2.fill", tip: "Toggle tap sound") { [weak self] in self?.onToggleSound?() }
        row.addArrangedSubview(undoButton)
        row.addArrangedSubview(captureButton)
        row.addArrangedSubview(magnifierButton)
        row.addArrangedSubview(soundButton)
        exitButton = button(symbol: "xmark", tip: Preferences.shortcut(for: .exitPointer).help("Turn pointer off")) { [weak self] in self?.onExit?() }
        row.addArrangedSubview(exitButton)
        permissionButton = NSButton(title: "Allow Drawing…", target: self, action: #selector(fixPermission))
        permissionButton.bezelStyle = .rounded
        permissionButton.isHidden = true
        permissionButton.toolTip = "Open Accessibility settings to allow drawing. Interact still works."
        root.addArrangedSubview(permissionButton)
        for tool in DrawingTool.allCases {
            let b = button(symbol: tool.symbol, tip: Preferences.shortcut(for: PresentationAction(rawValue: tool.rawValue)!).help("\(tool.title) tool")) { [weak self] in self?.onTool?(tool) }
            toolButtons[tool] = b
            tools.addArrangedSubview(b)
        }
        tools.addArrangedSubview(Self.divider())
        for color in InkChoice.allCases {
            let b = button(image: Self.colorImage(color.resolved(for: PointerStyle.saved)), tip: color.title, side: 24) { Preferences.inkChoice = color }
            colors[color] = b
            tools.addArrangedSubview(b)
        }
        tools.addArrangedSubview(Self.divider())
        clearButton = button(symbol: "trash", tip: Preferences.clearShortcut.help("Clear Drawing")) { [weak self] in self?.onClear?() }
        tools.addArrangedSubview(clearButton)
        NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        refresh()
    }

    static func surface() -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 16
            return glass
        }
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true
        return effect
    }

    private static func container(in view: NSView) -> NSView {
        if #available(macOS 26, *), let glass = view as? NSGlassEffectView {
            let content = NSView()
            glass.contentView = content
            return content
        }
        return view
    }

    private func refresh() {
        let styles = PointerCatalog.quickStyles
        if styles != shownStyles {
            for b in styleButtons.values { actions[b] = nil; b.removeFromSuperview() }
            shownStyles = styles
            styleButtons.removeAll()
            for style in styles {
                let b = button(image: Self.icon(for: style), tip: style.title) { [weak self] in self?.onPick?(style) }
                styleButtons[style] = b
                pointerStrip.addArrangedSubview(b)
            }
        }
        for (style, b) in styleButtons { b.selected = style == current }
        for (tool, b) in toolButtons {
            b.selected = tool == Preferences.drawingTool
            b.toolTip = Preferences.shortcut(for: PresentationAction(rawValue: tool.rawValue)!).help("\(tool.title) tool")
        }
        for (color, b) in colors {
            b.selected = color == Preferences.inkChoice
            b.image = Self.colorImage(color.resolved(for: current ?? PointerStyle.saved))
        }
        interact.state = Preferences.pointerMode.isInteractive ? .on : .off
        interact.toolTip = Preferences.shortcut(for: .mode).help("On: use apps normally. Off: draw on screen.")
        tools.isHidden = Preferences.pointerMode == .point
        exitButton.toolTip = Preferences.shortcut(for: .exitPointer).help("Turn pointer off")
        undoButton.toolTip = Preferences.shortcut(for: .undo).help("Undo annotation")
        clearButton.toolTip = Preferences.clearShortcut.help("Clear Drawing")
        captureButton.toolTip = Preferences.shortcut(for: .capture).help("Take Screenshot")
        let position = Preferences.toolbarPosition
        let resetPosition = previousPreferencePosition != nil && position == nil
        if resetPosition { remembersMoves = false }
        resize()
        if resetPosition, let screen = screen { place(on: screen) }
        previousPreferencePosition = position
    }
    func select(_ style: PointerStyle) { current = style; refresh() }
    func setMode(_ value: PointerMode) { interact.state = value.isInteractive ? .on : .off; tools.isHidden = value.isInteractive; resize() }
    func setUndoEnabled(_ value: Bool) { undoButton.isEnabled = value }
    func setCapturing(_ value: Bool) { captureButton.isEnabled = !value }
    func setSoundOn(_ value: Bool) {
        soundButton.image = NSImage(systemSymbolName: value ? "speaker.wave.2.fill" : "speaker.slash.fill", accessibilityDescription: "Tap sound")
        soundButton.toolTip = value ? "Mute tap sound" : "Unmute tap sound"
    }
    func setNeedsPermission(_ needed: Bool) { permissionButton.isHidden = !needed; resize() }
    func center(of style: PointerStyle) -> CGPoint? {
        guard let b = styleButtons[style] else { return nil }
        let r = panel.convertToScreen(b.convert(b.bounds, to: nil))
        return CGPoint(x: r.midX, y: r.midY)
    }
    func place(on screen: NSScreen) {
        self.screen = screen
        let origin = Preferences.toolbarPosition ?? CGPoint(x: screen.visibleFrame.midX - panel.frame.width / 2, y: screen.visibleFrame.minY + 16)
        let wasSaving = savingPosition
        savingPosition = true
        panel.setFrameOrigin(clamped(origin, on: screen))
        savingPosition = wasSaving
    }
    private func clamped(_ point: CGPoint, on screen: NSScreen) -> CGPoint {
        let area = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        return CGPoint(x: min(max(point.x, area.minX), max(area.minX, area.maxX - panel.frame.width)).rounded(),
                       y: min(max(point.y, area.minY), max(area.minY, area.maxY - panel.frame.height)).rounded())
    }
    private func savePosition() {
        var point = panel.frame.origin
        if let items = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(panel.windowNumber)) as? [[String: Any]],
           let bounds = items.first?[kCGWindowBounds as String] as? NSDictionary,
           let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) {
            // AppKit can deliver its final move notification after performDrag returns.
            point = CGPoint(x: rect.minX, y: (NSScreen.screens.first?.frame.height ?? 0) - rect.maxY)
        }
        savingPosition = true
        defer { savingPosition = false }
        let position = (panel.screen ?? screen).map { clamped(point, on: $0) } ?? point
        if position != point { panel.setFrameOrigin(position) }
        Preferences.recordToolbarPosition(position)
        previousPreferencePosition = position
    }
    func windowDidMove(_ notification: Notification) {
        guard remembersMoves, !savingPosition else { return }
        Preferences.recordToolbarPosition(panel.frame.origin)
        previousPreferencePosition = panel.frame.origin
    }
    func resetPosition() { Preferences.toolbarPosition = nil; if let screen = panel.screen ?? screen { place(on: screen) } }
    func hide() { hideHint(); setRevealed(false) }
    func setMagnifying(_ enabled: Bool) { magnifierButton.selected = enabled }
    func setRevealed(_ value: Bool) {
        // Reconcile the native panel, including after deactivate/reactivate.
        // A cached flag can say hidden while an ordered panel is still opaque.
        panel.ignoresMouseEvents = !value
        panel.alphaValue = value ? 1 : 0
        if value {
            if !panel.isVisible { panel.orderFrontRegardless() }
        } else if panel.isVisible {
            panel.orderOut(nil)
        }
    }
    private func resize() {
        let origin = panel.frame.origin
        let wasSaving = savingPosition
        savingPosition = true
        defer { savingPosition = wasSaving }
        root.layoutSubtreeIfNeeded()
        panel.setContentSize(root.fittingSize)
        panel.setFrameOrigin(screen.map { clamped(origin, on: $0) } ?? origin)
    }
    func showHint(_ parts: [(key: String, text: String)]) {
        showMessage(parts.map { $0.key + " " + $0.text }.joined(separator: "  ·  "))
    }
    func showMessage(_ text: String) {
        hideHint()
        let p = Panel(contentRect: CGRect(x: 0, y: 0, width: 320, height: 40), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true
        p.level = panel.level; p.collectionBehavior = panel.collectionBehavior; p.ignoresMouseEvents = true
        let bg = Self.surface()
        p.contentView = bg
        let content = Self.container(in: bg)
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)
        ])
        p.setContentSize(CGSize(width: min(640, label.fittingSize.width + 32), height: 40))
        p.setFrameOrigin(CGPoint(x: panel.frame.midX - p.frame.width / 2, y: panel.frame.maxY + 8))
        p.orderFrontRegardless()
        hint = p
        let work = DispatchWorkItem { [weak self] in self?.hideHint() }
        hintWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
    func hideHint() { hintWork?.cancel(); hintWork = nil; hint?.orderOut(nil); hint = nil }

    func snapshot() -> NSBitmapImageRep? { bitmap(panel) }
    func snapshotHint() -> NSBitmapImageRep? { hint.flatMap(bitmap) }
    func snapshotInkTray() -> NSBitmapImageRep? { bitmap(panel) }
    private func bitmap(_ window: NSWindow) -> NSBitmapImageRep? {
        guard let view = window.contentView else { return nil }
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }
    private func button(image: NSImage? = nil, symbol: String? = nil, tip: String, side: CGFloat = 32, action: @escaping () -> Void) -> Button {
        let b = Button()
        b.isBordered = false; b.bezelStyle = .regularSquare; b.focusRingType = .none
        b.wantsLayer = true; b.layer?.cornerRadius = 8
        b.image = image ?? symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: tip) }
        b.imageScaling = image == nil ? .scaleNone : .scaleProportionallyUpOrDown
        b.contentTintColor = .labelColor
        b.toolTip = tip; b.setAccessibilityLabel(tip)
        b.widthAnchor.constraint(equalToConstant: side).isActive = true
        b.heightAnchor.constraint(equalToConstant: side).isActive = true
        b.target = self; b.action = #selector(tapped(_:))
        actions[b] = action
        return b
    }
    @objc private func tapped(_ sender: Button) { actions[sender]?() }
    @objc private func modeChanged() { onMode?(interact.state == .on ? .point : .draw) }
    @objc private func fixPermission() { onFixPermission?() }
    private static func divider() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.widthAnchor.constraint(equalToConstant: 1).isActive = true
        line.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return line
    }
    private static func colorImage(_ color: CGColor) -> NSImage {
        NSImage(size: CGSize(width: 24, height: 24), flipped: false) { rect in
            NSColor(cgColor: color)?.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4)).fill()
            NSColor.labelColor.withAlphaComponent(0.2).setStroke()
            NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4)).stroke()
            return true
        }
    }
    static func icon(for style: PointerStyle) -> NSImage? {
        if let image = PresentationPointerArtwork.icon(for: style) { return image }
        if style == .laser { return colorImage(Ink.red) }
        return style.assetName.flatMap(HandAsset.thumbnail)
    }
}
