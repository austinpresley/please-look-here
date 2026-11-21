import AppKit

final class Toolbar: NSObject, NSWindowDelegate {
    private var observers: [NSObjectProtocol] = []
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
    private typealias Button = ControlIconButton
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
    var onAllPointers: (() -> Void)?
    var onRedo: (() -> Void)?
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
    private let context = NSView()
    private var cursorButton: Button!
    private var pickerButton: Button!
    private var allPointersButton: Button!
    private var paletteButton: Button!
    private let picker = NSPopover()
    private var trackingPalette = false
    private var redoButton: Button!
    private var currentMode = Preferences.pointerMode
    private var pendingDrawing = false
    private var needsPermission = false
    private var toolButtons: [DrawingTool: Button] = [:]
    private var styleButtons: [PointerStyle: Button] = [:]
    var favoriteButtons: [PointerStyle: ControlIconButton] { styleButtons }
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
    func wantsReveal(mouse: CGPoint, deadline: Date, now: Date = Date()) -> Bool {
        picker.isShown || trackingPalette || frame.insetBy(dx: -48, dy: -32).contains(mouse) || now < deadline
    }
    var windows: [NSWindow] { [panel] + (hint.map { [$0] } ?? []) + (picker.contentViewController?.view.window.map { [$0] } ?? []) }

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
        cursorButton = button(symbol: "cursorarrow", tip: "Cursor: use apps normally") { [weak self] in self?.onMode?(.point) }
        pickerButton = button(symbol: Preferences.drawingTool.symbol, tip: "Choose drawing tool") { [weak self] in self?.showPicker() }
        row.addArrangedSubview(cursorButton); row.addArrangedSubview(pickerButton)
        row.addArrangedSubview(Self.divider())
        context.widthAnchor.constraint(equalToConstant: FloatingToolbarLayout.context).isActive = true
        context.heightAnchor.constraint(equalToConstant: 28).isActive = true
        for stack in [pointerStrip, tools] {
            stack.translatesAutoresizingMaskIntoConstraints = false; context.addSubview(stack)
            NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: context.leadingAnchor), stack.centerYAnchor.constraint(equalTo: context.centerYAnchor)])
        }
        row.addArrangedSubview(context)
        row.addArrangedSubview(Self.divider())
        undoButton = button(symbol: "arrow.uturn.backward", tip: "Undo") { [weak self] in self?.onUndo?() }
        redoButton = button(symbol: "arrow.uturn.forward", tip: "Redo") { [weak self] in self?.onRedo?() }
        clearButton = button(symbol: "trash", tip: "Clear drawing") { [weak self] in self?.onClear?() }
        captureButton = button(symbol: "camera", tip: "Screenshot") { [weak self] in self?.onCapture?() }
        magnifierButton = button(symbol: "plus.magnifyingglass", tip: "Magnifier") { [weak self] in self?.onMagnifier?() }
        soundButton = button(symbol: "speaker.wave.2", tip: "Tap sound") { [weak self] in self?.onToggleSound?() }
        for b in [undoButton, redoButton, clearButton] { b?.isEnabled = false; row.addArrangedSubview(b!) }
        row.addArrangedSubview(Self.divider())
        for b in [captureButton, magnifierButton, soundButton] { row.addArrangedSubview(b!) }
        row.addArrangedSubview(Self.divider())
        exitButton = button(image: ControlArtwork.hiddenHand(), tip: "Hide pointer") { [weak self] in self?.onExit?() }
        row.addArrangedSubview(exitButton)
        permissionButton = NSButton(title: "Allow Drawing…", target: self, action: #selector(fixPermission))
        permissionButton.bezelStyle = .rounded
        permissionButton.toolTip = "Drawing needs Accessibility access. Cursor remains available."
        // The permission path is in the tool picker, so the toolbar never changes size.
        let pickerContent = NSViewController()
        let grid = NSStackView(); grid.orientation = .vertical; grid.spacing = 4
        grid.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        var toolRow = NSStackView(); toolRow.orientation = .horizontal; toolRow.spacing = 4
        for (i, tool) in ControlTool.drawingTools.enumerated() {
            if i == 4 { grid.addArrangedSubview(toolRow); toolRow = NSStackView(); toolRow.orientation = .horizontal; toolRow.spacing = 4 }
            let b = button(symbol: tool.symbol, tip: tool.title) { [weak self] in self?.picker.performClose(nil); self?.onTool?(tool) }
            toolButtons[tool] = b; toolRow.addArrangedSubview(b)
        }
        grid.addArrangedSubview(toolRow); grid.addArrangedSubview(permissionButton)
        pickerContent.view = grid; picker.contentViewController = pickerContent; picker.behavior = .transient; picker.animates = false
        for color in [InkChoice.match, .red, .yellow, .green, .blue, .purple, .white, .black] {
            let b = button(image: ControlArtwork.ink(color, pointer: PointerStyle.saved), tip: color.title) { Preferences.inkChoice = color }
            colors[color] = b; tools.addArrangedSubview(b)
        }
        paletteButton = button(symbol: "paintpalette", tip: "All ink colors") { [weak self] in self?.showPalette() }
        tools.addArrangedSubview(paletteButton)
        observers = [Preferences.changed, CustomHands.changed].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        }
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
            for b in styleButtons.values { actions[b] = nil }
            pointerStrip.arrangedSubviews.forEach { pointerStrip.removeArrangedSubview($0); $0.removeFromSuperview() }
            shownStyles = styles; styleButtons.removeAll()
            for style in styles {
                let b = button(image: Self.icon(for: style), tip: style.title) { [weak self] in self?.onPick?(style) }
                styleButtons[style] = b; pointerStrip.addArrangedSubview(b)
            }
            allPointersButton = button(image: UsabilityGlyph.library.image, tip: "All pointers") { [weak self] in self?.onAllPointers?() }
            pointerStrip.addArrangedSubview(allPointersButton)
        }
        let drawing = currentMode == .draw || pendingDrawing
        for (style, b) in styleButtons { b.updateFavorite(style); b.updateSelection(style == current) }
        for (tool, b) in toolButtons { b.updateSelection(drawing && tool == Preferences.drawingTool, notReady: needsPermission) }
        for (color, b) in colors {
            b.updateSelection(color == Preferences.inkChoice)
            b.image = ControlArtwork.ink(color, pointer: current ?? PointerStyle.saved)
            b.toolTip = color == .match ? "Match pointer: uses the current pointer's ink" : color.title
        }
        cursorButton.updateSelection(!drawing)
        pickerButton.updateSelection(drawing, notReady: drawing && needsPermission)
        pickerButton.image = ControlArtwork.toolPicker(Preferences.drawingTool)
        pickerButton.toolTip = "\(Preferences.drawingTool.title). Open drawing tool picker.\(needsPermission ? " Drawing needs access." : "")"
        tools.isHidden = !drawing; pointerStrip.isHidden = drawing
        permissionButton.isHidden = !needsPermission
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
    func setMode(_ value: PointerMode, pending: Bool = false) { currentMode = value; pendingDrawing = pending; refresh() }
    func setRedoEnabled(_ value: Bool) { redoButton.isEnabled = value }
    func setUndoEnabled(_ value: Bool) { undoButton.isEnabled = value }
    func setClearEnabled(_ value: Bool) { clearButton.isEnabled = value }
    func setCapturing(_ value: Bool) { captureButton.isEnabled = !value }
    func setSoundOn(_ value: Bool, status: String? = nil) {
        let state = TapSoundState(pointerEnabled: Preferences.pointerConfiguration(for: (current ?? PointerStyle.saved).rawValue).soundEnabled,
                                  outputMuted: Preferences.soundMuted || Preferences.soundVolume == 0)
        soundButton.image = NSImage(systemSymbolName: state.symbol, accessibilityDescription: "Tap sound")
        soundButton.toolTip = "\(state.title). Toggle current pointer tap sound."
        soundButton.setAccessibilityValue(state.title)
    }
    func setNeedsPermission(_ needed: Bool) { needsPermission = needed; refresh() }
    func showPicker() {
        picker.contentSize = picker.contentViewController?.view.fittingSize ?? CGSize(width: 160, height: 100)
        picker.show(relativeTo: pickerButton.bounds, of: pickerButton, preferredEdge: .maxY)
    }
    private func showPalette() {
        let menu = NSMenu()
        for ink in InkChoice.allCases {
            let item = NSMenuItem(title: ink.title, action: #selector(pickInk(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = ink.rawValue; item.image = ControlArtwork.ink(ink, pointer: current ?? PointerStyle.saved)
            item.image?.size = CGSize(width: 20, height: 20); item.state = Preferences.inkChoice == ink ? .on : .off; menu.addItem(item)
        }
        trackingPalette = true
        defer { trackingPalette = false }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: paletteButton)
    }
    @objc private func pickInk(_ sender: NSMenuItem) { if let raw = sender.representedObject as? String, let ink = InkChoice(rawValue: raw) { Preferences.inkChoice = ink } }
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
    func hide() { picker.performClose(nil); hideHint(); setRevealed(false) }
    func setMagnifying(_ enabled: Bool) { magnifierButton.updateSelection(enabled) }
    func setRevealed(_ value: Bool) {
        if !value { picker.performClose(nil) }
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

    func verify(_ request: [String: Any]) -> [String: Any] {
        if let selection = request["selection"] as? String {
            if let tool = DrawingTool(rawValue: selection) { Preferences.drawingTool = tool; setMode(.draw) }
            else { setMode(.point) }
        }
        if let permission = request["permission"] as? Bool { setNeedsPermission(!permission) }
        if request["open"] as? Bool == true { if let screen = NSScreen.main { place(on: screen) }; setRevealed(true) }
        if request["open"] as? Bool == false { hide() }
        if request["picker"] as? Bool == true { showPicker() }
        var result = UsabilityVerification.capture(panel, request: request)
        let shared = ["cursor": cursorButton!, "tool": pickerButton!, "undo": undoButton!, "redo": redoButton!, "clear": clearButton!, "capture": captureButton!, "magnifier": magnifierButton!, "sound": soundButton!, "hide": exitButton!]
        result["buttons"] = shared.mapValues { b -> [CGFloat] in let r = b.convert(b.bounds, to: panel.contentView); return [r.minX, r.minY, r.width, r.height] }
        result["contextWidth"] = context.frame.width
        result["favorites"] = Dictionary(uniqueKeysWithValues: styleButtons.map { style, button in
            (style.rawValue, ["label": button.accessibilityLabel() ?? "", "tooltip": button.toolTip ?? "",
                              "artwork": style.assetName.map(HandAsset.imageSignature) ?? style.rawValue])
        })
        if let path = request["snapshot"] as? String {
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: path.replacingOccurrences(of: ".png", with: "-layout.json"))) }
        }
        if let pickerPath = request["pickerSnapshot"] as? String {
            var child = request; child["snapshot"] = pickerPath
            result["picker"] = UsabilityVerification.capture(picker.contentViewController?.view.window, request: child)
        }
        return result
    }
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
    private func button(image: NSImage? = nil, symbol: String? = nil, tip: String, side: CGFloat = FloatingToolbarLayout.button, action: @escaping () -> Void) -> Button {
        let b = Button(); b.title = ""
        b.isBordered = false; b.bezelStyle = .regularSquare; b.focusRingType = .none
        b.wantsLayer = true; b.layer?.cornerRadius = 8
        b.image = image ?? symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: tip) }
        if image == nil { b.image?.isTemplate = true }
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
