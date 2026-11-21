import AppKit

/// Owns status-item presentation, the native popover, and its input lease.
/// Standard AppKit controls keep keyboard and AX behavior in the responder chain.
final class MenuBarControls: NSObject, NSPopoverDelegate, NSMenuDelegate {
    private let overlay: OverlayController
    private let perform: ([String: Any]) -> String
    private let checkForUpdates: () -> Void
    private let popover = NSPopover()
    private let content = NSView()
    private let root = NSStackView()
    private let pointer = NSSwitch()
    private let favorites = NSStackView()
    private let tools = NSStackView()
    private let colors = NSStackView()
    private let permission = NSStackView()
    private var toolButtons: [ControlToolKey: ControlIconButton] = [:]
    private var styleButtons: [PointerStyle: ControlIconButton] = [:]
    var favoriteButtons: [PointerStyle: ControlIconButton] { styleButtons }
    private var inkButtons: [InkChoice: ControlIconButton] = [:]
    private var fixture: PresentationControlsState?
    private enum ControlToolKey: Hashable { case cursor, tool(DrawingTool) }
    private let summary = NSTextField(labelWithString: "")
    private let message = NSTextField(wrappingLabelWithString: "")
    private let pointerTitle = NSTextField(labelWithString: "Pointer Off")
    private var buttons: [String: NSButton] = [:]
    private var actions: [NSControl: () -> Void] = [:]
    private var rows: [NSView] = []
    private var statusItem: NSStatusItem!
    private lazy var commands = MenuBarCommands(overlay: overlay)
    private var tracking = Set<ObjectIdentifier>()
    private var timer: Timer?
    private var monitors: [Any] = []
    private var catalog: [PointerStyle] = []
    private var wantsControls = false
    private var explicitClosing = false
    private var statusWasOpen = false
    private var actionCounts: [String: Int] = [:]
    private var opening = false
    private var testAnchor: NSPanel?
    private var width: CGFloat = 320
    private var widthConstraint: NSLayoutConstraint!
    var statusFrame: CGRect? {
        guard let button = statusItem?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }
    var shortcutConflicts: [String: String] = [:] {
        didSet { commands.shortcutConflicts = shortcutConflicts }
    }
    var shortcutDiagnostics: [[String: Any]] { commands.diagnostics }
    var openPractice: (() -> Void)? {
        didSet { commands.openPractice = openPractice }
    }

    init(overlay: OverlayController, perform: @escaping ([String: Any]) -> String, checkForUpdates: @escaping () -> Void) {
        self.overlay = overlay; self.perform = perform; self.checkForUpdates = checkForUpdates
        super.init()
    }
    deinit { timer?.invalidate(); monitors.forEach(NSEvent.removeMonitor) }
    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self; statusItem.button?.action = #selector(statusClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.setAccessibilityLabel("Look Here Please controls")
        commands.perform = { [weak self] in self?.send($0) }
        commands.openControls = { [weak self] in
            self?.wantsControls = true
            DispatchQueue.main.async { self?.show() }
        }
        commands.checkForUpdates = checkForUpdates
        commands.allMenus.forEach { $0.delegate = self }
        build()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.popover.isShown || !self.tracking.isEmpty else { return }
            self.refresh(); self.syncLease()
        }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
        // Native transient behavior is the no-permission fallback. With drawing
        // access, InputTap consumes outside dismissal pairs before AppKit sees them.
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown], handler: { [weak self] event in
            guard let self, self.popover.isShown, self.tracking.isEmpty, event.keyCode == 53 else { return event }
            self.close(); return nil
        }) { monitors.append(monitor) }
        refresh()
    }
    private func build() {
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        let controller = NSViewController(); controller.view = content
        popover.contentViewController = controller
        root.orientation = .vertical; root.alignment = .leading; root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        root.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(root)
        widthConstraint = content.widthAnchor.constraint(equalToConstant: width)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor), root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor), root.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            widthConstraint
        ])
        pointerTitle.stringValue = "Show pointer"
        pointerTitle.font = .systemFont(ofSize: 13, weight: .medium) // grid: ok system text
        pointer.target = self; pointer.action = #selector(tapped(_:)); pointer.setAccessibilityLabel("Show pointer")
        actions[pointer] = { [weak self] in self?.send("toggle") }
        let hand = NSImageView(image: NSImage(systemSymbolName: "hand.point.up.left", accessibilityDescription: "Pointer")!)
        hand.widthAnchor.constraint(equalToConstant: 20).isActive = true
        let sound = button("sound", "Tap sound", "speaker.wave.2") { [weak self] in self?.send("toggle-current-sound") }
        let settings = button("settings", "Settings…", "gearshape") { [weak self] in self?.send("settings") }
        addRow(horizontal([hand, pointerTitle, pointer, flex(), sound, settings]))
        for stack in [favorites, tools, colors, permission] { stack.orientation = .horizontal; stack.spacing = 4; stack.alignment = .centerY }
        addRow(favorites)
        for choice in ControlTool.all {
            let key: ControlToolKey = choice == .cursor ? .cursor : .tool({ if case .drawing(let t) = choice { return t }; return .pen }())
            let b = button("tool.\(choice.title)", choice.title, choice.symbol) { [weak self] in
                guard let self else { return }
                if case .drawing(let tool) = choice { self.overlay.chooseToolFromControls(tool) }
                else { self.send("interact", ["enabled": true]) }
                self.refresh(); self.resize()
            }
            toolButtons[key] = b; tools.addArrangedSubview(b)
        }
        addRow(permission)
        addRow(tools)
        for ink in InkChoice.allCases {
            let b = button("ink.\(ink.rawValue)", ink.title, "circle.fill") { [weak self] in self?.send("configure", ["settings": ["ink": ink.rawValue]]) }
            inkButtons[ink] = b; colors.addArrangedSubview(b)
        }
        addRow(colors)
        let lock = NSImageView(image: NSImage(systemSymbolName: "lock", accessibilityDescription: nil)!)
        let needs = NSTextField(labelWithString: "Drawing needs access")
        needs.font = .systemFont(ofSize: 12)
        let allow = button("allow", "Allow drawing", "lock.open", title: "Allow") { [weak self] in self?.close(); self?.overlay.requestDrawingPermission() }
        permission.addArrangedSubview(lock); permission.addArrangedSubview(needs); permission.addArrangedSubview(flex()); permission.addArrangedSubview(allow)
        addDivider()
        addRow(horizontal([
            button("undo", "Undo", "arrow.uturn.backward") { [weak self] in self?.send("undo") },
            button("redo", "Redo", "arrow.uturn.forward") { [weak self] in self?.send("redo") },
            button("clear", "Clear drawing", "trash") { [weak self] in self?.send("clear") }, flex(),
            button("capture", "Screenshot", "camera") { [weak self] in self?.send("capture") },
            button("magnifier", "Magnifier", "plus.magnifyingglass") { [weak self] in
                guard let self else { return }; self.send("magnifier", ["enabled": !self.overlay.isMagnifying])
            }
        ]))
        summary.font = .systemFont(ofSize: 12); summary.textColor = .secondaryLabelColor
        addRow(summary)
        message.font = .systemFont(ofSize: 12); message.textColor = .secondaryLabelColor; message.isHidden = true
        addRow(message)
        content.layoutSubtreeIfNeeded()
        popover.contentSize = CGSize(width: width, height: root.fittingSize.height)
    }
    private func addRow(_ row: NSView) {
        root.addArrangedSubview(row); rows.append(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -32).isActive = true
    }
    private func addDivider() {
        let line = NSBox(); line.boxType = .separator; addRow(line)
    }
    private func horizontal(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views); row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 8
        return row
    }
    private func flex() -> NSView { let view = NSView(); view.setContentHuggingPriority(.defaultLow, for: .horizontal); return view }
    private func button(_ id: String, _ name: String, _ symbol: String, title: String = "", action: @escaping () -> Void) -> ControlIconButton {
        let button = ControlIconButton(title: title, target: self, action: #selector(tapped(_:)))
        button.bezelStyle = .regularSquare; button.isBordered = false; button.focusRingType = .none
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        if title.isEmpty { button.widthAnchor.constraint(equalToConstant: 28).isActive = true }
        button.contentTintColor = .labelColor
        button.imageScaling = .scaleProportionallyDown
        button.image = id == "all" ? UsabilityGlyph.library.image : NSImage(systemSymbolName: symbol, accessibilityDescription: name)
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        button.setAccessibilityLabel(name); button.toolTip = name; actions[button] = action; buttons[id] = button
        return button
    }
    func refresh() {
        guard statusItem != nil else { return }
        // Status-item windows can carry a different appearance from NSApp.
        // The app's explicit Light/Dark choice applies to its controls as well.
        let appearance = NSApp.effectiveAppearance
        if popover.appearance?.name != appearance.name { popover.appearance = appearance }
        let on = overlay.isActive
        let image = Bundle.main.image(forResource: on ? "menubar_on" : "menubar_off")
            ?? NSImage(systemSymbolName: on ? "hand.point.up.left.fill" : "hand.point.up.left", accessibilityDescription: "Look Here Please")
        image?.size = CGSize(width: 18, height: 18); image?.isTemplate = true // grid: ok retained status artwork size
        statusItem.button?.image = image
        let state = fixture ?? overlay.controlsState
        statusItem.button?.toolTip = "Look Here Please · \(state.value). Click for controls. Right-click for commands."
        statusItem.button?.setAccessibilityValue(state.value)
        pointer.state = state.pointerVisible ? .on : .off
        pointer.setAccessibilityValue(state.pointerVisible ? "Shown" : "Hidden")
        pointer.toolTip = Preferences.toggleShortcut.help("Show or hide pointer. Choices stay editable while hidden.")
        let styles = PointerCatalog.quickStyles
        if catalog != styles {
            for b in styleButtons.values { actions[b] = nil }
            favorites.arrangedSubviews.forEach { favorites.removeArrangedSubview($0); $0.removeFromSuperview() }
            catalog = styles; styleButtons.removeAll()
            for style in styles {
                let b = button("pointer.\(style.rawValue)", style.title, "hand.point.up.left") { [weak self] in self?.send("style", ["style": style.rawValue]) }
                b.image = Toolbar.icon(for: style); b.imageScaling = .scaleProportionallyUpOrDown
                styleButtons[style] = b; favorites.addArrangedSubview(b)
            }
            favorites.addArrangedSubview(flex())
            favorites.addArrangedSubview(button("all", "All pointers", "square.grid.2x2") { [weak self] in self?.close(); self?.overlay.showAllPointersFromControls() })
        }
        for (style, b) in styleButtons { b.updateFavorite(style); b.updateSelection(style == overlay.style) }
        for (key, b) in toolButtons {
            let choice: ControlTool = key == .cursor ? .cursor : { if case .tool(let t) = key { return .drawing(t) }; return .cursor }()
            b.updateSelection(choice == state.selection, notReady: choice == state.selection && state.notReady)
            b.isEnabled = !state.capturing
            b.toolTip = choice == .cursor ? "Cursor: use apps normally" : "\(choice.title): draw on screen"
        }
        for (ink, b) in inkButtons {
            b.image = ControlArtwork.ink(ink, pointer: overlay.style)
            b.imageScaling = .scaleProportionallyUpOrDown
            b.updateSelection(ink == Preferences.inkChoice)
            b.toolTip = ink == .match ? "Match pointer: \(overlay.style.title) ink" : ink.title
        }
        colors.isHidden = !state.showsColors
        permission.isHidden = state.drawingAllowed && !state.notReady
        permission.wantsLayer = true; permission.layer?.cornerRadius = 8
        appearance.performAsCurrentDrawingAppearance { permission.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.12).cgColor }
        summary.stringValue = state.notReady ? "\(state.tool.title) kept for later" : state.value
        summary.toolTip = state.value
        buttons["undo"]?.isEnabled = overlay.canUndo && !overlay.isCapturing
        buttons["redo"]?.isEnabled = overlay.canRedo && !overlay.isCapturing
        buttons["clear"]?.isEnabled = overlay.inkStrokes > 0 && !overlay.isCapturing
        buttons["undo"]?.toolTip = Preferences.shortcut(for: .undo).help("Undo annotation")
        buttons["redo"]?.toolTip = Preferences.shortcut(for: .redo).help("Redo annotation")
        buttons["clear"]?.toolTip = Preferences.clearShortcut.help("Clear drawing")
        buttons["capture"]?.isEnabled = !overlay.isCapturing
        buttons["capture"]?.toolTip = Preferences.shortcut(for: .capture).help("Take screenshot")
        buttons["magnifier"]?.state = overlay.isMagnifying ? .on : .off
        buttons["magnifier"]?.isEnabled = !overlay.isCapturing
        buttons["magnifier"]?.setAccessibilityValue(overlay.isMagnifying ? "On" : "Off")
        buttons["magnifier"]?.toolTip = Preferences.shortcut(for: .magnifier).help("Toggle magnification")
        let sound = TapSoundState(pointerEnabled: overlay.soundOn, outputMuted: Preferences.soundMuted || Preferences.soundVolume == 0)
        buttons["sound"]?.image = NSImage(systemSymbolName: sound.symbol, accessibilityDescription: "Tap sound")
        buttons["sound"]?.toolTip = "\(sound.title). Toggle current pointer tap sound."
        buttons["sound"]?.setAccessibilityValue(sound.title)
        buttons["settings"]?.toolTip = Preferences.shortcut(for: .settings).help("Open Settings")
        commands.refresh()
    }
    private func send(_ operation: String, _ fields: [String: Any] = [:]) {
        send(fields.merging(["version": 1, "operation": operation]) { _, b in b })
    }
    private func send(_ request: [String: Any]) {
        actionCounts[request["operation"] as? String ?? "", default: 0] += 1
        let leavesControls = ["capture", "capture-region", "settings", "magnifier", "gesture", "radial-open"].contains(request["operation"] as? String ?? "")
        if leavesControls { close() }
        let result = perform(request)
        message.stringValue = result; message.isHidden = result.isEmpty
        refresh() // Never leave a native switch showing its requested value after rejection.
        if popover.isShown { resize() }
    }
    @objc private func tapped(_ sender: NSControl) { actions[sender]?() }
    @objc private func statusClicked() {
        let wasOpen = statusWasOpen || popover.isShown
        statusWasOpen = false
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            showStatusCommands()
        } else if wasOpen { close() } else { show() }
    }
    func statusClickFromTap(secondary: Bool) {
        // The existing tap owned both halves. Do not also send this click to
        // AppKit, where transient dismissal could retarget its release.
        if secondary {
            // Native menu tracking must begin outside a main-dispatch callback.
            // A nested tracking loop cannot reenter that queue to serve control
            // clients while its original dispatch block is still on the stack.
            scheduleStatusCommands()
        } else { close() }
    }
    private func scheduleStatusCommands() {
        // Run native status tracking after the tap dispatch callback returns.
        RunLoop.main.perform(inModes: [.common]) { [weak self] in self?.showStatusCommands() }
    }
    func show() {
        guard !popover.isShown, let button = statusItem?.button, button.window != nil else { return }
        opening = true; wantsControls = false; statusWasOpen = false; message.isHidden = true; refresh()
        overlay.presentControls(true, nativeMenu: false, regions: statusFrame.map { [$0] } ?? [])
        NSApp.activate(ignoringOtherApps: true)
        let anchor = testAnchor?.contentView ?? button
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        popover.contentViewController?.view.window?.makeFirstResponder(nil)
        opening = false; syncLease()
    }
    func close() {
        wantsControls = false; statusWasOpen = false; explicitClosing = true
        commands.allMenus.forEach { $0.cancelTrackingWithoutAnimation() }
        popover.performClose(nil)
        explicitClosing = false; testAnchor?.orderOut(nil); testAnchor = nil; syncLease()
    }
    func popoverWillClose(_ notification: Notification) {
        // Native fallback when Accessibility is unavailable and there is no tap.
        if !explicitClosing, statusFrame?.contains(NSEvent.mouseLocation) == true { statusWasOpen = true }
    }
    private func resize() {
        content.layoutSubtreeIfNeeded()
        popover.contentSize = CGSize(width: width, height: root.fittingSize.height)
    }
    private func syncLease() {
        var frames = statusFrame.map { [$0] } ?? []
        if popover.isShown, let window = content.window { frames.append(window.frame) }
        overlay.presentControls(opening || popover.isShown || !tracking.isEmpty, nativeMenu: !tracking.isEmpty, regions: frames)
    }
    private func showStatusCommands() {
        refresh(); close()
        tracking.insert(ObjectIdentifier(commands.menu)); syncLease()
        statusItem.menu = commands.menu; statusItem.button?.performClick(nil); statusItem.menu = nil
        tracking.remove(ObjectIdentifier(commands.menu)); syncLease()
        if wantsControls { show() }
    }
    func popoverDidShow(_ notification: Notification) { content.window?.title = "Look Here Please Controls"; syncLease() }
    func popoverDidClose(_ notification: Notification) { syncLease() }
    func menuWillOpen(_ menu: NSMenu) { tracking.insert(ObjectIdentifier(menu)); refresh(); syncLease() }
    func menuDidClose(_ menu: NSMenu) { tracking.remove(ObjectIdentifier(menu)); syncLease() }

    // Available only behind test mode + the isolated S-023 suite gate.
    func verify(_ request: [String: Any]) -> [String: Any] {
        if let selection = request["selection"] as? String {
            let tool = DrawingTool(rawValue: selection)
            fixture = PresentationControlsState(mode: tool == nil ? .point : .draw, tool: tool ?? Preferences.drawingTool,
                pointerVisible: request["pointer"] as? Bool ?? true, drawingAllowed: request["permission"] as? Bool ?? true)
        }
        if let theme = request["appearance"] as? String, ["light", "dark"].contains(theme) { NSApp.appearance = NSAppearance(named: theme == "dark" ? .darkAqua : .aqua) }
        if let edge = request["anchor"] as? String, ["left", "right"].contains(edge), let screen = NSScreen.main {
            close()
            let area = screen.visibleFrame
            let panel = NSPanel(contentRect: CGRect(x: edge == "left" ? area.minX + 4 : area.maxX - 8,
                                                    y: area.maxY - 4, width: 4, height: 4),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false; panel.level = .statusBar; panel.title = "S-023 test anchor"
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.ignoresMouseEvents = true
            panel.orderFrontRegardless(); testAnchor = panel
        }
        if let narrow = request["width"] as? Int, [280, 320].contains(narrow) {
            width = max(320, CGFloat(narrow)); widthConstraint.constant = width; resize()
        }
        if request["open"] as? Bool == true { show() }
        if request["open"] as? Bool == false { close() }
        refresh(); resize()
        if let path = request["snapshot"] as? String, popover.isShown, let window = content.window,
           path.hasPrefix("/"), path.hasSuffix(".png"), NSApp.isActive, window.isKeyWindow,
           let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]),
           let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path)); writeLayout(path.replacingOccurrences(of: ".png", with: "-layout.json"))
        }
        func frame(_ rect: CGRect) -> [CGFloat] { [rect.minX, rect.minY, rect.width, rect.height] }
        return ["visible": popover.isShown, "window": content.window?.windowNumber ?? 0, "key": content.window?.isKeyWindow ?? false,
                "frame": content.window.map { frame($0.frame) } ?? [], "statusFrame": statusFrame.map(frame) ?? [],
                "menus": commands.diagnostics, "tracking": tracking.count, "summary": summary.stringValue,
                "appearance": popover.effectiveAppearance.name.rawValue,
                "actionCounts": actionCounts, "message": message.stringValue,
                "pointer": pointer.state == .on, "interact": (fixture ?? overlay.controlsState).selection == .cursor, "tool": (fixture ?? overlay.controlsState).tool.rawValue,
                "choice": overlay.style.rawValue, "choices": catalog.map(\.rawValue),
                "reduceMotion": NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                "reduceTransparency": NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                "buttons": buttons.mapValues { ["enabled": $0.isEnabled, "label": $0.accessibilityLabel() ?? "", "value": String(describing: $0.accessibilityValue() ?? "")] }]
    }
    private func writeLayout(_ path: String) {
        var probes: [[String: Any]] = [["kind": "area", "name": "controls", "area": "controls", "inset": 16,
                                      "x": 0, "y": 0, "width": content.bounds.width, "height": content.bounds.height]]
        for (index, row) in rows.enumerated() where !row.isHidden {
            // AppKit aligns optical alignment rects. Native cells deliberately
            // extend their drawing bounds beyond those edges by a few points.
            let f = row.convert(row.alignmentRect(forFrame: row.bounds), to: content)
            probes.append(["kind": "probe", "name": "row\(index)", "area": "controls", "edge": "lead", "inset": 0,
                           "x": f.minX, "y": f.minY, "width": f.width, "height": f.height])
        }
        if let data = try? JSONSerialization.data(withJSONObject: ["probes": probes], options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
