import AppKit

struct ClearRecoveryState {
    private(set) var revision: UUID?
    private(set) var captureHidden = false
    var valid: Bool { revision != nil }
    var visible: Bool { valid && !captureHidden }
    mutating func cleared(at revision: UUID) { self.revision = revision }
    mutating func documentChanged(to revision: UUID) { if self.revision != revision { dismiss() } }
    mutating func dismiss() { revision = nil }
    mutating func hideForCapture(_ hidden: Bool) { captureHidden = hidden }
    func canUndo(at revision: UUID) -> Bool { self.revision == revision }
}

/// Shares the ring's material, palette and transparency fallback.
final class QuickRecoverySurface: NSView {
    private let wash = NSView()
    private var material: NSView!
    let cornerRadius: CGFloat
    init(frame: NSRect = .zero, cornerRadius: CGFloat = 20) {
        self.cornerRadius = cornerRadius
        super.init(frame: frame)
        wantsLayer = true
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView(); glass.style = .regular; glass.cornerRadius = cornerRadius
            glass.contentView = NSView(); material = glass
        } else {
            let effect = NSVisualEffectView(); effect.material = .hudWindow; effect.blendingMode = .behindWindow; effect.state = .active
            effect.wantsLayer = true; effect.layer?.cornerRadius = cornerRadius; effect.layer?.masksToBounds = true
            material = effect
        }
        wash.wantsLayer = true; wash.layer?.cornerRadius = cornerRadius
        addSubview(material); addSubview(wash)
        updatePalette()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() { super.layout(); material.frame = bounds; wash.frame = bounds; updatePalette() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updatePalette() }
    private func updatePalette() {
        let tokens = RadialAppearance.system(effectiveAppearance)
        material?.isHidden = !tokens.usesMaterial
        if #available(macOS 26, *), let glass = material as? NSGlassEffectView { glass.tintColor = RadialAppearance.color(tokens.background, alpha: 0.25) }
        wash.layer?.backgroundColor = RadialAppearance.color(tokens.background, alpha: tokens.usesMaterial ? (tokens.dark ? 0.55 : 0.65) : 1).cgColor
        wash.layer?.borderColor = RadialAppearance.color(tokens.text, alpha: tokens.contrast ? 1 : 0.2).cgColor
        wash.layer?.borderWidth = tokens.contrast ? 2 : 1 / (window?.backingScaleFactor ?? 2)
        layer?.shadowColor = NSColor.black.cgColor; layer?.shadowOpacity = tokens.dark ? 0.22 : 0.14
        layer?.shadowRadius = 8; layer?.shadowOffset = CGSize(width: 0, height: -2) // grid: ok restrained 2-point downward HUD shadow
        layer?.shadowPath = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    }
}
final class QuickRecoveryButton: NSButton {
    var prominent = false
    private let focusHalo = CAShapeLayer(), focusRing = CAShapeLayer()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true; layer?.masksToBounds = false
        for outline in [focusHalo, focusRing] { outline.fillColor = nil; layer?.addSublayer(outline) }
        focusRing.lineWidth = 2
    }
    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return super.becomeFirstResponder() }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return super.resignFirstResponder() }
    override func draw(_ dirtyRect: NSRect) {
        let tokens = RadialAppearance.system(effectiveAppearance)
        let pill = NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14)
        if prominent || isHighlighted {
            RadialAppearance.color(prominent ? tokens.selection : tokens.text, alpha: prominent ? (isHighlighted ? 0.85 : 1) : 0.1).setFill(); pill.fill()
        }
        let color = RadialAppearance.color(prominent ? tokens.onSelection : tokens.secondary)
        if prominent {
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: color]
            let size = (title as NSString).size(withAttributes: attributes)
            (title as NSString).draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
        } else {
            let cross = NSBezierPath(); cross.move(to: CGPoint(x: 10, y: 10)); cross.line(to: CGPoint(x: 18, y: 18)); cross.move(to: CGPoint(x: 10, y: 18)); cross.line(to: CGPoint(x: 18, y: 10))
            color.setStroke(); cross.lineWidth = 1.5; cross.lineCapStyle = .round; cross.stroke()
        }
        // Match the wheel/list's blue ring and contrasting halo. Keeping the
        // outline outside the 28-point fill leaves a visible gap around it.
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let focused = window?.isKeyWindow == true && window?.firstResponder === self
        focusHalo.isHidden = !focused; focusRing.isHidden = !focused
        let path = CGPath(roundedRect: bounds.insetBy(dx: -3, dy: -3), cornerWidth: 17, cornerHeight: 17, transform: nil) // grid: ok focus sits 3 points beyond the 14-point pill radius
        focusHalo.path = path; focusRing.path = path
        focusHalo.lineWidth = tokens.contrast ? 5 : 4
        focusHalo.strokeColor = RadialAppearance.color(tokens.dark ? tokens.background : 0xFFFFFF).cgColor
        focusRing.strokeColor = NSColor.systemBlue.cgColor
        CATransaction.commit()
    }
}

/// Nonactivating recovery. Dismissal removes both controls from the AX tree.
final class ClearRecovery: NSObject, NSWindowDelegate {
    private final class Panel: AnnotationResponderPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
        var onDismiss: (() -> Void)?
        override func cancelOperation(_ sender: Any?) { onDismiss?() }
    }
    let window: NSPanel
    private let surface = QuickRecoverySurface(frame: CGRect(x: 12, y: 12, width: 234, height: 40)) // grid: ok prototype's 16/6-point pill padding and 28-point actions
    private let title = NSTextField(labelWithString: "Drawing cleared")
    private let undo = QuickRecoveryButton(title: "Undo", target: nil, action: nil)
    private let dismiss = QuickRecoveryButton(title: "✕", target: nil, action: nil)
    private(set) var state = ClearRecoveryState()
    var onUndo: (() -> Void)?
    var onContextChanged: (() -> Void)?
    var onRedo: (() -> Void)?
    var canRedo: () -> Bool = { false }
    private let focusDriver: QuickControlsFocus
    private var focusRestoration: QuickControlsFocusRestoration?
    private var tookFocus = false
    var currentRevision: () -> UUID = { UUID() }
    var diagnostics: [String: Any] { ["valid": state.valid, "visible": window.isVisible, "revision": state.revision.map { $0.uuidString as Any } ?? NSNull(), "captureHidden": state.captureHidden, "keyWindow": window.isKeyWindow, "window": window.windowNumber, "accessibilityHidden": surface.isAccessibilityHidden(), "undoHeight": undo.frame.height, "dismissSize": [dismiss.frame.width, dismiss.frame.height], "dismissLabel": dismiss.accessibilityLabel() ?? "", "undoFocused": window.firstResponder === undo, "dismissFocused": window.firstResponder === dismiss] }
    init(focus: QuickControlsFocus = .system) {
        focusDriver = focus
        window = Panel(contentRect: CGRect(x: 0, y: 0, width: 258, height: 64), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false) // grid: ok 234-point pill plus 12-point shadow insets
        super.init()
        window.title = "Drawing cleared"; window.isReleasedWhenClosed = false; window.hidesOnDeactivate = false
        window.delegate = self
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 4)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.becomesKeyOnlyIfNeeded = true
        if let panel = window as? Panel {
            panel.onDismiss = { [weak self] in self?.dismissRecovery() }
            panel.annotationUndo.onUndo = { [weak self] in self?.restoreDrawing() }
            panel.annotationUndo.canUndo = { [weak self] in guard let self else { return false }; return self.state.canUndo(at: self.currentRevision()) }
            panel.annotationUndo.onRedo = { [weak self] in self?.onRedo?() }
            panel.annotationUndo.canRedo = { [weak self] in self?.canRedo() ?? false }
        }
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 258, height: 64)); content.wantsLayer = true; content.addSubview(surface) // grid: ok pill plus shadow insets
        window.contentView = content
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = NSColor(name: nil) { RadialAppearance.color(RadialAppearance.system($0).text) }
        undo.prominent = true; undo.isBordered = false; undo.target = self; undo.action = #selector(restoreDrawing); undo.setAccessibilityLabel("Undo")
        dismiss.isBordered = false; dismiss.target = self; dismiss.action = #selector(dismissRecovery); dismiss.setAccessibilityLabel("Dismiss")
        undo.keyEquivalent = "\r"; undo.focusRingType = .none; dismiss.focusRingType = .none
        undo.nextKeyView = dismiss; dismiss.nextKeyView = undo
        undo.toolTip = "Undo Clear. Focus this recovery with Command-Shift-U from Quick controls."
        title.frame = CGRect(x: 16, y: 10, width: 108, height: 20)
        undo.frame = CGRect(x: 132, y: 6, width: 60, height: 28)
        dismiss.frame = CGRect(x: 200, y: 6, width: 28, height: 28)
        [title, undo, dismiss].forEach { surface.addSubview($0) }
        update()
    }
    func show(revision: UUID, on bounds: CGRect) {
        state.cleared(at: revision)
        window.makeFirstResponder(nil)
        window.setFrameOrigin(CGPoint(x: bounds.midX - window.frame.width / 2, y: bounds.minY + 24))
        update(); announce("Drawing cleared. Undo is available.")
    }
    func documentChanged(to revision: UUID) { state.documentChanged(to: revision); update() }
    func windowDidBecomeKey(_ notification: Notification) { undo.needsDisplay = true; dismiss.needsDisplay = true; onContextChanged?() }
    func windowDidResignKey(_ notification: Notification) { undo.needsDisplay = true; dismiss.needsDisplay = true; onContextChanged?() }
    func hideForCapture(_ hidden: Bool) { state.hideForCapture(hidden); update() }
    @discardableResult func focus(ignoringModifiers: NSEvent.ModifierFlags = [], takingRestoration: (() -> QuickControlsFocusRestoration?)? = nil) -> Bool {
        guard state.visible, state.canUndo(at: currentRevision()) else { return false }
        // Every wheel must relinquish ownership, even when recovery still owes
        // the original restoration. Drop later tokens without restoring them.
        let restoration = takingRestoration?()
        if !tookFocus {
            focusRestoration = restoration ?? focusDriver.save()
            tookFocus = true
        }
        (window as? Panel)?.annotationUndo.ignoredModifiers = ignoringModifiers
        let focused = focusDriver.focus(window, undo, false)
        if !focused { restoreFocus() }
        onContextChanged?()
        return focused && state.visible && ownsKeyboardFocus
    }
    var ownsKeyboardFocus: Bool { focusDriver.isKey(window) }
    /// The disposable snapshot bridge selects the responder directly, so its
    /// appearance fixture is independent of the system's Full Keyboard Access.
    func verifyDismissFocus() {
        guard window.isKeyWindow else { return }
        window.makeFirstResponder(dismiss)
    }
    @objc func dismissRecovery() { state.dismiss(); update() }
    @objc func restoreDrawing() {
        guard state.canUndo(at: currentRevision()) else { state.dismiss(); update(); return }
        state.dismiss(); update(); onUndo?(); announce("Drawing restored")
    }
    private func update() {
        surface.setAccessibilityHidden(!state.visible)
        undo.isHidden = !state.visible; dismiss.isHidden = !state.visible
        if state.visible { window.orderFrontRegardless() }
        else {
            window.orderOut(nil)
            restoreFocus()
        }
        onContextChanged?()
    }
    private func restoreFocus() {
        guard tookFocus else { return }
        tookFocus = false
        let restoration = focusRestoration; focusRestoration = nil
        restoration?.restore()
    }
    private func announce(_ message: String) { NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested, userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue]) }
}

/// Capturing is permitted only after every transient window was hidden and the
/// compositor has had a turn. The IDs are also excluded by ScreenCaptureKit.
struct CaptureExclusionState {
    enum Phase: String { case idle, hidden, ready, finished }
    private(set) var phase: Phase = .idle
    private(set) var windowIDs: [CGWindowID] = []
    mutating func begin(windowIDs: [CGWindowID]) { self.windowIDs = windowIDs; phase = .hidden }
    mutating func compositorDrained() { if phase == .hidden { phase = .ready } }
    var canCapture: Bool { phase == .ready }
    mutating func finish() { phase = .finished }
}
