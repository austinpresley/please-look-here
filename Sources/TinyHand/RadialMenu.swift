import AppKit

/// Owns a transient native control. Commands are handed back to the app's
/// validated control bridge; this module never changes presentation preferences.
final class RadialMenu {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
    private let panel: NSPanel
    private let canvas = RadialCanvas()
    private var feedback: NSPanel?
    private var feedbackID = UUID()
    private(set) var session: RadialSession?
    private(set) var lastResult = ""
    var releaseSelects = true // Changed only by the gated native comparison seam.
    var perform: (([String: Any]) -> String)?
    var onClose: (() -> Void)?
    var visible: Bool { panel.isVisible && panel.alphaValue > 0.01 }
    var window: NSWindow { panel }
    var diagnostics: [String: Any] {
        ["visible": visible, "window": panel.windowNumber, "frame": [panel.frame.minX, panel.frame.minY, panel.frame.width, panel.frame.height],
         "center": session.map { [$0.geometry.center.x, $0.geometry.center.y] } ?? [], "armed": session?.armed ?? false,
         "group": session?.group ?? "", "page": session?.page ?? 0, "pages": session?.pages ?? 0,
         "highlighted": session?.candidate?.id ?? "", "lastResult": lastResult,
         "releaseSelects": releaseSelects, "reduceMotion": NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
         "items": session?.items.enumerated().map { ["id": $0.element.id, "title": $0.element.title, "slot": $0.offset, "selected": $0.element.selected, "enabled": $0.element.enabled] as [String: Any] } ?? []]
    }
    init() {
        panel = Panel(contentRect: CGRect(x: 0, y: 0, width: RadialGeometry.size, height: RadialGeometry.size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Look Here Please Quick Controls"
        panel.animationBehavior = .none
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.ignoresMouseEvents = true; panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 4)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = canvas
        canvas.onPress = { [weak self] index in
            guard let self else { return }
            if index == -1 { self.close(); return }
            if index == -2 { self.session?.back(); self.update(); return }
            if let command = self.session?.activate(index) { self.commit(command) }
            else { self.update() }
        }
    }
    func open(at point: CGPoint, style: PointerStyle, mode: PointerMode, canUndo: Bool, canRedo: Bool, hasInk: Bool) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }), screen.visibleFrame.width >= RadialGeometry.size, screen.visibleFrame.height >= RadialGeometry.size else { lastResult = "Quick controls need a display at least 592 points wide and tall."; onClose?(); return }
        func request(_ operation: String, _ fields: [String: Any] = [:]) -> [String: Any] { fields.merging(["version": 1, "operation": operation]) { _, b in b } }
        func command(_ id: String, _ title: String, _ symbol: String, _ op: String, _ fields: [String: Any] = [:], selected: Bool = false, enabled: Bool = true) -> RadialItem { RadialItem(id: id, title: title, symbol: symbol, selected: selected, enabled: enabled, request: request(op, fields)) }
        let root = [RadialItem(id: "pointers", title: "Pointer", symbol: "hand.point.up.left.fill", group: "pointer"),
                    RadialItem(id: "colors", title: "Color", symbol: "paintpalette.fill", group: "color"),
                    RadialItem(id: "tools", title: "Tools", symbol: "pencil.tip", group: "tools"),
                    command("interact", mode.isInteractive ? "Interact On" : "Interact Off", "cursorarrow", "interact", ["enabled": !mode.isInteractive], selected: mode.isInteractive),
                    RadialItem(id: "history", title: "History", symbol: "arrow.uturn.backward", group: "history"),
                    RadialItem(id: "more", title: "More", symbol: "ellipsis", group: "more")]
        let pointers = PointerCatalog.selectableStyles.map { value in
            RadialItem(id: value.rawValue, title: value.title, symbol: value.symbol, selected: style == value, style: value, request: request("style", ["style": value.rawValue]))
        }
        let colors = InkChoice.allCases.map { command($0.rawValue, $0.title, "paintpalette", "configure", ["settings": ["ink": $0.rawValue]], selected: Preferences.inkChoice == $0) }
        let tools = DrawingTool.allCases.map { command($0.rawValue, $0.title, $0.symbol, "tool", ["tool": $0.rawValue], selected: Preferences.drawingTool == $0 && !mode.isInteractive) }
        let history = [command("undo", "Undo", "arrow.uturn.backward", "undo", enabled: canUndo), command("redo", "Redo", "arrow.uturn.forward", "redo", enabled: canRedo), command("clear", "Clear Drawing", "trash", "clear", enabled: hasInk)]
        let more = [command("capture", "Screenshot", "camera", "capture"), command("sound", "Tap Sound", "speaker.wave.2", "toggle-current-sound", selected: style == .laser ? Preferences.laserSound : Preferences.handSound), command("toolbar", "Show toolbar", "rectangle.topthird.inset.filled", "configure", ["settings": ["showToolbar": !Preferences.showToolbar]], selected: Preferences.showToolbar), command("settings", "Settings…", "gearshape", "settings"), command("off", "Pointer Off", "power", "off")]
        feedback?.orderOut(nil)
        canvas.summary = "\(style.title) · \(mode.isInteractive ? "Interact On" : Preferences.drawingTool.title)"
        canvas.toolTip = canvas.summary
        let geometry = RadialGeometry(cursor: point, bounds: screen.visibleFrame)
        session = RadialSession(geometry: geometry, root: root, groups: ["pointer": pointers, "color": colors, "tools": tools, "history": history, "more": more])
        session?.move(point)
        panel.setFrame(geometry.frame, display: true)
        update(); canvas.needsDisplay = true; panel.orderFrontRegardless()
    }
    func move(to point: CGPoint) { session?.move(point); update() }
    func updateHistory(canUndo: Bool, canRedo: Bool, hasInk: Bool) {
        guard session != nil else { return }
        session?.updateHistory(canUndo: canUndo, canRedo: canRedo, hasInk: hasInk)
        update()
    }
    func release() {
        if releaseSelects, let command = session?.candidate?.request { commit(command) } else { close() }
    }
    func click(at point: CGPoint) {
        move(to: point)
        if let command = session?.candidate?.request { commit(command) } else { close() }
    }
    func close() { session = nil; panel.orderOut(nil); onClose?() }
    private func commit(_ command: [String: Any]) {
        let location = session?.geometry.center
        let title = session?.candidate?.title ?? "Quick controls"
        close()
        lastResult = perform?(command) ?? "Action unavailable"
        if let location { showFeedback(lastResult == "Selected" ? title : lastResult, at: location) }
    }
    private func showFeedback(_ message: String, at point: CGPoint) {
        let p = Panel(contentRect: CGRect(x: point.x - 160, y: point.y - 24, width: 320, height: 48), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.animationBehavior = .none
        p.isOpaque = false; p.backgroundColor = .windowBackgroundColor; p.ignoresMouseEvents = true
        p.level = panel.level; p.isReleasedWhenClosed = false
        let label = NSTextField(wrappingLabelWithString: message)
        label.frame = CGRect(x: 12, y: 8, width: 296, height: 32); label.alignment = .center
        label.font = .systemFont(ofSize: 13, weight: .medium); label.setAccessibilityLabel(message)
        p.contentView?.addSubview(label)
        feedback?.orderOut(nil); feedback = p
        let id = UUID(); feedbackID = id
        p.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
            if self?.feedbackID == id { self?.feedback?.orderOut(nil); self?.feedback = nil }
        }
    }
    private func update() { panel.effectiveAppearance.performAsCurrentDrawingAppearance { canvas.update(session) } }
    func snapshot(to path: String) -> Bool {
        guard visible, path.hasPrefix("/"), path.hasSuffix(".png"),
              let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(panel.windowNumber), [.boundsIgnoreFraming, .bestResolution]),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            canvas.writeLayout(to: path.replacingOccurrences(of: ".png", with: "-layout.json"))
            return true
        } catch { return false }
    }
}

private final class RadialCanvas: NSView {
    var onPress: ((Int) -> Void)?
    private var session: RadialSession?
    private var buttons: [NSButton] = []
    private var dot: NSView?
    private var rendered = ""
    var summary = ""
    override init(frame: NSRect) { super.init(frame: frame); setAccessibilityLabel("Quick controls"); setAccessibilityRole(.group) }
    required init?(coder: NSCoder) { fatalError() }
    func update(_ session: RadialSession?) {
        self.session = session
        let signature = session.map { s in
            "\(s.group ?? "")/\(s.page)/\(s.highlighted ?? -1)/\(s.armed)/\(s.pageArmed)/\(effectiveAppearance.name.rawValue)/" + s.items.map { "\($0.id):\($0.enabled):\($0.selected)" }.joined(separator: ",")
        } ?? ""
        if signature == rendered, let session {
            dot?.setFrameOrigin(CGPoint(x: session.point.x - session.geometry.frame.minX - 8, y: session.point.y - session.geometry.frame.minY - 8))
            return
        }
        rendered = signature
        buttons.forEach { $0.removeFromSuperview() }; buttons.removeAll()
        dot?.removeFromSuperview()
        guard let session else { needsDisplay = true; return }
        let center = CGPoint(x: RadialGeometry.size / 2, y: RadialGeometry.size / 2)
        for (i, item) in session.items.enumerated() where !item.title.isEmpty {
            let point = RadialGeometry.point(slot: i, radius: session.group == nil ? RadialGeometry.rootRadius : RadialGeometry.childRadius, center: center)
            let size = CGSize(width: session.group == nil ? 88 : 112, height: 56)
            let b = NSButton(frame: CGRect(x: ((point.x - size.width / 2) / 4).rounded() * 4, y: ((point.y - size.height / 2) / 4).rounded() * 4, width: size.width, height: size.height))
            b.title = (item.selected ? "✓ " : "") + item.title
            b.font = .systemFont(ofSize: 12, weight: .medium)
            b.image = item.style.flatMap(Toolbar.icon) ?? NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)
            b.imagePosition = .imageAbove; b.imageScaling = .scaleProportionallyDown
            b.cell?.wraps = true; b.isBordered = false; b.wantsLayer = true
            b.layer?.cornerRadius = 12
            b.layer?.backgroundColor = (session.highlighted == i ? NSColor.selectedContentBackgroundColor : NSColor.controlBackgroundColor).cgColor
            b.contentTintColor = session.highlighted == i ? .selectedMenuItemTextColor : .labelColor
            b.layer?.borderWidth = item.selected ? 2 : 1
            b.layer?.borderColor = (item.selected ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
            b.isEnabled = item.enabled; b.tag = i; b.target = self; b.action = #selector(press(_:))
            b.toolTip = item.title; b.setAccessibilityLabel(item.title); b.setAccessibilityValue(item.selected ? "Selected" : "")
            addSubview(b); buttons.append(b)
        }
        let hub = NSButton(frame: CGRect(x: center.x - 72, y: center.y - 32, width: 144, height: 64))
        hub.title = session.group == nil ? "Cancel Quick Controls" : "Back to Quick Controls"
        hub.setAccessibilityLabel(hub.title)
        hub.title = ""; hub.isBordered = false; hub.tag = session.group == nil ? -1 : -2
        hub.target = self; hub.action = #selector(press(_:)); addSubview(hub); buttons.append(hub)
        let p = CGPoint(x: session.point.x - session.geometry.frame.minX, y: session.point.y - session.geometry.frame.minY)
        let indicator = RadialDot(frame: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16))
        indicator.setAccessibilityElement(false); addSubview(indicator); dot = indicator
        needsDisplay = true
    }
    func writeLayout(to path: String) {
        func probe(_ name: String, _ frame: CGRect, kind: String = "probe") -> [String: Any] {
            ["kind": kind, "name": name, "area": "radial", "inset": 0, "x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
        }
        let probes = [probe("radial", bounds, kind: "area"), probe("help", CGRect(x: 72, y: 4, width: 448, height: 40))]
            + buttons.map { probe($0.accessibilityLabel() ?? $0.title, $0.frame) }
        if let data = try? JSONSerialization.data(withJSONObject: ["window": ["width": bounds.width, "height": bounds.height], "probes": probes], options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: path)) }
    }
    @objc private func press(_ sender: NSButton) { onPress?(sender.tag) }
    override func draw(_ dirtyRect: NSRect) {
        guard let session else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        NSColor.windowBackgroundColor.withAlphaComponent(0.97).setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: session.group == nil ? 88 : 12, dy: session.group == nil ? 88 : 12)).fill()
        let hub = CGRect(x: center.x - 76, y: center.y - 36, width: 152, height: 72)
        NSColor.controlBackgroundColor.setFill(); NSBezierPath(roundedRect: hub, xRadius: 16, yRadius: 16).fill()
        let title = session.armed ? session.title : "Enter center"
        let detail = session.group == nil ? "Center cancels" : (session.pageArmed ? "Move inward to go back" : "Move inward to arm")
        let page = session.pages > 1 ? " · \(session.page + 1)/\(session.pages)" : ""
        (title + page).draw(in: CGRect(x: center.x - 72, y: center.y + 4, width: 144, height: 20), withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor, .paragraphStyle: Self.centered])
        detail.draw(in: CGRect(x: center.x - 72, y: center.y - 20, width: 144, height: 20), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: Self.centered])
        let footer = CGRect(x: 72, y: 4, width: 448, height: 40)
        NSColor.windowBackgroundColor.setFill(); NSBezierPath(roundedRect: footer, xRadius: 12, yRadius: 12).fill()
        summary.draw(in: CGRect(x: 80, y: 24, width: 432, height: 16), withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.labelColor, .paragraphStyle: Self.centered])
        "Move, then release to select · Esc cancels".draw(in: CGRect(x: 80, y: 8, width: 432, height: 16), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: Self.centered])
    }
    private static var centered: NSParagraphStyle { let p = NSMutableParagraphStyle(); p.alignment = .center; p.lineBreakMode = .byTruncatingTail; return p }
}

private final class RadialDot: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.labelColor.setFill(); NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
        NSColor.windowBackgroundColor.setFill(); NSBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4)).fill()
    }
}
