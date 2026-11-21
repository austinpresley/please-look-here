import AppKit

/// Window and app adapter. The session owns inspection, navigation, activation,
/// copy and focus ownership; renderer and accessibility consume that state.
final class RadialMenu {
    private final class Panel: AnnotationResponderPanel {
        var acceptsKeys = false
        var onKey: ((RadialKey, RadialKeyModifiers) -> Void)?
        var onPointer: ((CGPoint, Bool) -> Void)?
        override var canBecomeKey: Bool { acceptsKeys }
        override var canBecomeMain: Bool { false }
        override func keyDown(with event: NSEvent) {
            var modifiers: RadialKeyModifiers = []
            if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
            if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
            if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
            if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
            guard modifiers.intersection([.command, .option, .control]).isEmpty, let key = RadialKey.keyCode(Int64(event.keyCode)) else { super.keyDown(with: event); return }
            onKey?(key, modifiers)
        }
        override func mouseDown(with event: NSEvent) { onPointer?(convertPoint(toScreen: event.locationInWindow), true) }
        override func mouseUp(with event: NSEvent) { onPointer?(convertPoint(toScreen: event.locationInWindow), false) }
    }
    private let panel: Panel
    private let renderer = RadialRenderer(frame: CGRect(x: 0, y: 0, width: 384, height: 384))
    private let list = QuickControlsList(frame: .zero)
    private let accessibility = RadialAccessibility()
    private(set) var session: RadialSession?
    private var inputSessionID: UInt?
    private var appearanceOverride: RadialAppearance?
    private var displayObserver: NSObjectProtocol?, accommodationObserver: NSObjectProtocol?
    private var focusObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private var appearanceObservation: NSKeyValueObservation?
    private let focus: QuickControlsFocus
    private var focusRestoration: QuickControlsFocusRestoration?
    private var tookFocus = false
    private var transferredFocus = false
    private weak var handedOffWindow: NSWindow?
    private var generation = UUID()
    private(set) var lastResult = ""
    var releaseSelects = true
    var perform: (([String: Any]) -> QuickCommandResult)?
    var onFailure: ((QuickCommandFailure) -> Void)?
    var onOpenBrowser: ((QuickControlsFocusRestoration?) -> Void)?
    var onOpenSettings: ((QuickControlsFocusRestoration?) -> Void)?
    var onWillPerform: ((String, CGRect) -> Void)?
    var onClose: ((UInt) -> Void)?
    var onVisibilityChanged: (() -> Void)?
    var onFocusOwnershipChanged: ((Bool) -> Void)?
    var visible: Bool { session != nil && panel.isVisible }
    var persistent: Bool { session?.mode == .persistent }
    var usesSystemCursor: Bool { persistent || session?.geometry.usesList == true }
    var window: NSWindow { panel }
    var annotationUndo: AnnotationUndoResponder { panel.annotationUndo }
    private var tokens: RadialAppearance { appearanceOverride ?? .system(panel.effectiveAppearance) }
    var diagnostics: [String: Any] {
        guard let session else { return ["visible": false, "lastResult": lastResult] }
        return ["visible": visible, "sessionID": inputSessionID ?? 0, "window": panel.windowNumber,
                "frame": Self.rect(panel.frame), "center": [session.geometry.center.x, session.geometry.center.y],
                "point": [session.point.x, session.point.y], "bounds": Self.rect(session.geometry.bounds),
                "mode": session.mode == .persistent ? "persistent" : "held", "list": session.geometry.usesList,
                "armed": session.armed, "group": session.group ?? "", "needNeutral": session.needNeutral, "outside": session.outside,
                "ownsFocus": session.ownsFocus, "keyboard": session.keyboard, "keyWindow": panel.isKeyWindow,
                "highlighted": session.inspected?.id ?? "", "candidate": session.candidate?.id ?? "", "lastResult": lastResult,
                "pendingTitle": session.pendingCopy.title, "pendingSubtitle": session.pendingCopy.subtitle,
                "releaseSelects": releaseSelects, "reduceMotion": tokens.reduceMotion, "opaque": tokens.opaque, "increaseContrast": tokens.contrast,
                "items": session.items.enumerated().map { ["id": $0.element.id, "title": $0.element.title, "slot": $0.offset, "selected": $0.element.selected, "enabled": $0.element.enabled, "reason": $0.element.reason, "angle": session.angle(for: $0.offset)] as [String: Any] }]
    }
    init(focus: QuickControlsFocus = .system) {
        self.focus = focus
        panel = Panel(contentRect: CGRect(x: 0, y: 0, width: 384, height: 384), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Look Here Please Quick controls"
        panel.animationBehavior = .none; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.ignoresMouseEvents = true; panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 4)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = renderer
        panel.onKey = { [weak self] key, modifiers in
            guard let self, let id = self.inputSessionID else { return }; self.key(key, modifiers: modifiers, sessionID: id)
        }
        panel.onPointer = { [weak self] point, down in
            guard let self, let id = self.inputSessionID else { return }
            if down { self.pointerDown(at: point, sessionID: id) } else { self.pointerUp(at: point, sessionID: id) }
        }
        list.onScroll = { [weak self] offset in
            guard let self else { return }
            self.session?.scrollList(to: offset)
            let geometry = self.list.semanticGeometry
            self.accessibility.refreshFrames(view: self.list, frames: geometry.frames, visibility: geometry.visible)
        }
        appearanceObservation = panel.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in self?.update() }
        displayObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.close() }
        accommodationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.update() }
        func observe(_ name: Notification.Name, in center: NotificationCenter, object: AnyObject? = nil, preservingHandoff: Bool = false, requiresOwnership: Bool = false) {
            let token = center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                guard let self, !preservingHandoff || !self.transferredFocus,
                      !requiresOwnership || self.tookFocus || self.transferredFocus else { return }
                self.cancelForFocusLoss()
            }
            focusObservers.append((center, token))
        }
        observe(NSWindow.didResignKeyNotification, in: .default, object: panel, preservingHandoff: true, requiresOwnership: true)
        let handoffResigned = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let window = note.object as? NSWindow, window === self.handedOffWindow else { return }
            self.cancelForFocusLoss()
        }
        focusObservers.append((.default, handoffResigned))
        observe(NSApplication.didResignActiveNotification, in: .default, requiresOwnership: true)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.sessionDidResignActiveNotification,
                     NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification] {
            observe(name, in: workspace)
        }
        for name in ["com.apple.screenIsLocked", "com.apple.screensaver.didstart"] {
            observe(Notification.Name(name), in: DistributedNotificationCenter.default())
        }
        let activation = workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != getpid() else { return }
            guard let self, self.tookFocus || self.transferredFocus else { return }
            self.cancelForFocusLoss()
        }
        focusObservers.append((workspace, activation))
    }
    deinit {
        if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) }
        if let accommodationObserver { NSWorkspace.shared.notificationCenter.removeObserver(accommodationObserver) }
        for (center, token) in focusObservers { center.removeObserver(token) }
    }
    func open(sessionID: UInt, at point: CGPoint, style: PointerStyle, mode: PointerMode, canUndo: Bool, canRedo: Bool, hasInk: Bool, invocation: RadialMode = .held, bounds: CGRect? = nil) {
        guard session == nil, let usable = bounds ?? NSScreen.screens.first(where: { $0.frame.contains(point) })?.visibleFrame else { return }
        generation = UUID(); inputSessionID = sessionID; accessibility.reset()
        annotationUndo.ignoredModifiers = invocation == .held ? (Preferences.radialTrigger == .option ? .option : Preferences.radialTrigger == .control ? .control : []) : []
        transferredFocus = false; handedOffWindow = nil
        focusRestoration = focus.save()
        renderer.pointerStyle = style; renderer.ink = Preferences.inkChoice; renderer.tool = Preferences.drawingTool
        let geometry = RadialGeometry(cursor: point, bounds: usable)
        session = RadialCatalog.make(geometry: geometry,
            state: currentState(style: style, mode: mode), favorites: Preferences.quickControlFavorites, pointers: PointerCatalog.entries,
            canUndo: canUndo, canRedo: canRedo, hasInk: hasInk, mode: invocation)
        session?.move(point)
        panel.alphaValue = 1
        update(); panel.orderFrontRegardless(); updateFocus()
        if let layer = panel.contentView?.layer { RadialRenderer.fade(layer, from: 0, to: 1, duration: tokens.openDuration) }
        onVisibilityChanged?()
    }
    private func currentState(style: PointerStyle, mode: PointerMode) -> RadialCurrentState {
        RadialCurrentState(pointerID: style.rawValue, ink: Preferences.inkChoice, tool: Preferences.drawingTool,
            interact: mode.isInteractive, tapSound: Preferences.pointerConfiguration(for: style.rawValue).soundEnabled,
            muted: Preferences.soundMuted, toolbar: Preferences.showToolbar)
    }
    func refresh(style: PointerStyle, mode: PointerMode) {
        guard session != nil else { return }
        renderer.pointerStyle = style; renderer.ink = Preferences.inkChoice; renderer.tool = Preferences.drawingTool
        session?.updateCurrent(currentState(style: style, mode: mode)); session?.updatePointers(PointerCatalog.entries); update()
    }
    func move(to point: CGPoint, sessionID: UInt) {
        guard inputSessionID == sessionID else { return }; session?.move(point); update()
    }
    func updateHistory(canUndo: Bool, canRedo: Bool, hasInk: Bool) {
        guard session != nil else { return }; session?.updateHistory(canUndo: canUndo, canRedo: canRedo, hasInk: hasInk); update()
    }
    func release(sessionID: UInt) {
        guard inputSessionID == sessionID, !cancelIfFocusLost() else { return }
        if releaseSelects, let item = session?.release() { commit(item) } else { close() }
    }
    func click(at point: CGPoint, sessionID: UInt) {
        guard inputSessionID == sessionID, !cancelIfFocusLost() else { return }
        move(to: point, sessionID: sessionID)
        if let item = session?.release() { commit(item) } else { close() }
    }
    func pointerDown(at point: CGPoint, sessionID: UInt) {
        guard inputSessionID == sessionID else { return }; session?.pointerDown(point); update()
    }
    func pointerUp(at point: CGPoint, sessionID: UInt) {
        guard inputSessionID == sessionID else { return }
        guard !cancelIfFocusLost() else { return }
        if let item = session?.pointerUp(point) { commit(item) }
        else if session?.closed == true { close() } else { update() }
    }
    func pointerCancel(sessionID: UInt) {
        guard inputSessionID == sessionID else { return }; session?.pointerCancelled()
        if session?.closed == true { close() } else { update() }
    }
    func key(_ key: RadialKey, modifiers: RadialKeyModifiers, sessionID: UInt) {
        guard inputSessionID == sessionID else { return }
        guard !cancelIfFocusLost() else { return }
        if let item = session?.key(key, modifiers: modifiers) { commit(item) }
        else if session?.closed == true { close() } else { update() }
    }
    func close(sessionID: UInt? = nil) {
        if let sessionID, inputSessionID != sessionID { return }
        guard session != nil else { return }
        let id = inputSessionID, closing = generation, duration = tokens.closeDuration
        inputSessionID = nil; session = nil; handedOffWindow = nil; accessibility.reset()
        onFocusOwnershipChanged?(false)
        panel.acceptsKeys = false
        let restoration = tookFocus ? focusRestoration : nil
        tookFocus = false; focusRestoration = nil
        restoration?.restore()
        if let id { onClose?(id) }; onVisibilityChanged?()
        if duration == 0 { panel.orderOut(nil) }
        else {
            if let layer = panel.contentView?.layer { RadialRenderer.fade(layer, from: 1, to: 0, duration: duration) }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                if self?.generation == closing { self?.panel.orderOut(nil) }
            }
        }
    }
    func closeImmediately() { close(); panel.orderOut(nil) }
    /// An external focus change ends ownership, without activating the context
    /// saved before opening. Explicit handoffs have already taken that token.
    func cancelForFocusLoss(sessionID: UInt? = nil) {
        if let sessionID, inputSessionID != sessionID { return }
        guard session != nil else { return }
        focusRestoration = nil; tookFocus = false
        closeImmediately()
    }
    @discardableResult func cancelIfFocusLost() -> Bool {
        guard session != nil else { return false }
        let owner = transferredFocus ? handedOffWindow : (tookFocus ? panel : nil)
        guard let owner, !focus.isKey(owner) || (tookFocus && !focus.isActive()) else { return false }
        cancelForFocusLoss(); return true
    }
    private func commit(_ item: RadialItem) {
        if item.opensBrowser {
            let restoration = takeFocusRestoration()
            closeImmediately()
            if let onOpenBrowser { onOpenBrowser(restoration) } else { restoration?.restore() }
            return
        }
        guard let command = item.request else { close(); return }
        if command["operation"] as? String == "settings" {
            let restoration = takeFocusRestoration()
            closeImmediately()
            if let onOpenSettings { onOpenSettings(restoration) } else { restoration?.restore() }
            return
        }
        if let bounds = session?.geometry.bounds { onWillPerform?(command["operation"] as? String ?? "", bounds) }
        close()
        let result = perform?(command) ?? .failure(.rejected(operation: command["operation"] as? String ?? "", code: "unavailable", reason: "The command is unavailable. Open Settings and try again."))
        lastResult = result.message
        if case .failure(let failure) = result { onFailure?(failure) }
        else { accessibility.announce(item.title) }
    }
    /// Recovery takes the original restoration obligation before making its panel
    /// key. Subsequent refreshes and queued closes cannot reclaim or restore it.
    @discardableResult func focusRecovery(_ recovery: ClearRecovery) -> Bool {
        let previous = handedOffWindow
        handedOffWindow = recovery.window
        let focused = recovery.focus(ignoringModifiers: session == nil ? [] : annotationUndo.ignoredModifiers, takingRestoration: { [self] in
            takeFocusRestoration()
        })
        if !focused {
            handedOffWindow = previous
            if transferredFocus { cancelForFocusLoss() }
        }
        return focused
    }
    func takeFocusRestoration() -> QuickControlsFocusRestoration? {
        guard session != nil, let restoration = focusRestoration else { return nil }
        focusRestoration = nil; tookFocus = false; transferredFocus = true
        session?.relinquishFocus(); panel.acceptsKeys = false
        onFocusOwnershipChanged?(false)
        return restoration
    }
    private func updateFocus() {
        guard !transferredFocus, let session, session.ownsFocus else { return }
        onFocusOwnershipChanged?(true)
        panel.acceptsKeys = true
        guard panel.isVisible else { return }
        if !tookFocus {
            tookFocus = true
            _ = focus.focus(panel, panel.contentView, true)
        }
    }
    private func activate(_ index: Int) -> Bool {
        guard !cancelIfFocusLost() else { return false }
        guard let session, session.items.indices.contains(index) else { return false }
        if !session.items[index].enabled { accessibility.announce(session.items[index].reason); return false }
        if let item = self.session?.activate(index) { commit(item) } else { update() }
        return true
    }
    private func inspect(_ index: Int) {
        guard !cancelIfFocusLost() else { return }
        session?.inspect(index, keyboard: true); update()
    }
    private func update() {
        guard let session else { return }
        panel.setFrame(session.panelFrame, display: true)
        let view: NSView
        if session.geometry.usesList {
            view = list; if panel.contentView !== list { panel.contentView = list }
            list.pointerStyle = renderer.pointerStyle; list.ink = renderer.ink; list.tool = renderer.tool
            list.frame = CGRect(origin: .zero, size: session.panelFrame.size); list.update(session, tokens: tokens)
            list.layoutSubtreeIfNeeded()
        } else {
            view = renderer; if panel.contentView !== renderer { panel.contentView = renderer }
            renderer.frame = CGRect(x: 0, y: 0, width: 384, height: 384); renderer.update(session, tokens: tokens)
        }
        panel.ignoresMouseEvents = session.mode == .held && !session.geometry.usesList
        updateFocus()
        let geometry = list.semanticGeometry
        let frames = session.geometry.usesList ? geometry.frames : renderer.layouts.map(\.frame)
        accessibility.update(session: session, view: view, frames: frames, visibility: session.geometry.usesList ? geometry.visible : [], currentSession: { [weak self] in self?.session }, activate: { [weak self] in self?.activate($0) ?? false }, inspect: { [weak self] in self?.inspect($0) }, back: { [weak self] in
            guard let self else { return }; if self.session?.group == nil { self.close() } else { self.session?.back(); self.update() }
        })
    }
    func snapshot(to path: String) -> Bool {
        guard visible, path.hasPrefix("/"), path.hasSuffix(".png"), !path.contains("\0"),
              let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(panel.windowNumber), [.boundsIgnoreFraming, .bestResolution]),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: URL(fileURLWithPath: path)); try writeLayout(to: path.replacingOccurrences(of: ".png", with: "-layout.json")); return true
        } catch { return false }
    }
    private func writeLayout(to path: String) throws {
        guard let session else { return }
        let items: [[String: Any]] = session.items.enumerated().map { index, item in
            let frames = session.geometry.usesList ? [session.listLayout.row(index, scroll: session.listScroll)] : renderer.layouts[index].visibleFrames
            return ["id": item.id, "angle": session.angle(for: index), "frames": frames.map(Self.rect), "enabled": item.enabled, "selected": item.selected]
        }
        let layout: [String: Any] = ["window": Self.rect(panel.frame), "state": diagnostics, "items": items,
                                    "scale": panel.backingScaleFactor, "outerRadius": 164, "originReserve": [182, 182, 20, 20]]
        try JSONSerialization.data(withJSONObject: layout, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: path))
    }
    private static func rect(_ rect: CGRect) -> [CGFloat] { [rect.minX, rect.minY, rect.width, rect.height] }

    /// Gated by ControlBridge. This drives the same model methods as native
    /// events, with accommodation overrides confined to this panel/session.
    func verify(_ request: [String: Any], style: PointerStyle, mode: PointerMode, canUndo: Bool, canRedo: Bool, hasInk: Bool) throws {
        struct Invalid: Error {}
        let allowed: Set<String> = ["event", "mode", "point", "bounds", "level", "highlighted", "keyboard", "appearance", "opaque", "increaseContrast", "reduceMotion", "key", "sessionID", "canUndo", "canRedo", "hasInk", "snapshot", "releaseSelects", "interact"]
        guard Set(request.keys).isSubset(of: allowed) else { throw Invalid() }
        for name in ["opaque", "increaseContrast", "reduceMotion", "keyboard", "canUndo", "canRedo", "hasInk", "releaseSelects", "interact"] {
            if let value = request[name] {
                guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { throw Invalid() }
            }
        }
        for name in ["event", "mode", "level", "highlighted", "appearance", "key", "snapshot"] {
            if let value = request[name], !(value is String) { throw Invalid() }
        }
        if let value = request["sessionID"] {
            guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.doubleValue.isFinite, number.doubleValue > 0, number.doubleValue.rounded() == number.doubleValue,
                  number.uintValue == inputSessionID else { throw Invalid() }
        }
        func numbers(_ value: Any?, count: Int) throws -> [CGFloat] {
            guard let array = value as? [NSNumber], array.count == count,
                  array.allSatisfy({ CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite }) else { throw Invalid() }
            return array.map { CGFloat($0.doubleValue) }
        }
        func point(_ value: Any?) throws -> CGPoint {
            let v = try numbers(value, count: 2); return CGPoint(x: v[0], y: v[1])
        }
        let mode: PointerMode = (request["interact"] as? Bool).map { $0 ? .point : .draw } ?? mode
        let event = request["event"] as? String ?? "state"
        guard ["open", "close", "move", "press", "release", "cancel", "key", "state"].contains(event) else { throw Invalid() }
        if let level = request["level"] as? String, !["root", "pointer", "color", "draw", "more"].contains(level) { throw Invalid() }
        if let appearance = request["appearance"] as? String, !["light", "dark"].contains(appearance) { throw Invalid() }
        if let invocation = request["mode"] as? String, !["held", "persistent"].contains(invocation) { throw Invalid() }
        if let value = request["point"] { _ = try point(value) }
        var reviewBounds: CGRect?
        if let value = request["bounds"] {
            let v = try numbers(value, count: 4)
            let rect = CGRect(x: v[0], y: v[1], width: v[2], height: v[3])
            guard v[2] > 24, v[3] > 24, rect.maxX.isFinite, rect.maxY.isFinite else { throw Invalid() }
            reviewBounds = rect
        }
        if let path = request["snapshot"] as? String {
            guard path.hasPrefix("/"), path.hasSuffix(".png"), !path.contains("\0") else { throw Invalid() }
        }
        if ["open", "move", "press"].contains(event) || (event == "release" && (persistent || session?.geometry.usesList == true)) { _ = try point(request["point"]) }
        if let id = request["highlighted"] as? String {
            let preview = session ?? RadialCatalog.make(geometry: RadialGeometry(cursor: .zero, bounds: CGRect(x: -1000, y: -1000, width: 2000, height: 2000)), state: currentState(style: style, mode: mode), favorites: Preferences.quickControlFavorites, pointers: PointerCatalog.entries, canUndo: canUndo, canRedo: canRedo, hasInk: hasInk)
            let level = request["level"] as? String ?? (event == "open" ? "root" : preview.group ?? "root")
            let ids = level == "root" ? preview.root.map(\.id) : ["back"] + (preview.groups[level] ?? []).map(\.id)
            guard ids.contains(id) else { throw Invalid() }
        }
        if event == "open" { appearanceOverride = nil; panel.appearance = nil }
        if let appearance = request["appearance"] as? String { panel.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua) }
        var overrides = appearanceOverride ?? RadialAppearance.system(panel.effectiveAppearance)
        overrides.dark = panel.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if let value = request["opaque"] as? Bool { overrides.opaque = value }
        if let value = request["increaseContrast"] as? Bool { overrides.contrast = value }
        if let value = request["reduceMotion"] as? Bool { overrides.reduceMotion = value }
        appearanceOverride = overrides
        if event == "open" {
            let invocation = request["mode"] as? String ?? "persistent"
            guard ["held", "persistent"].contains(invocation) else { throw Invalid() }
            let location = try point(request["point"])
            close(); panel.orderOut(nil)
            open(sessionID: UInt.random(in: 1...UInt.max), at: location, style: style, mode: mode,
                 canUndo: request["canUndo"] as? Bool ?? canUndo, canRedo: request["canRedo"] as? Bool ?? canRedo,
                 hasInk: request["hasInk"] as? Bool ?? hasInk, invocation: invocation == "held" ? .held : .persistent, bounds: reviewBounds)
        } else if event == "close" { close(); return }
        else if event == "move" { session?.move(try point(request["point"])) }
        else if event == "press" { session?.pointerDown(try point(request["point"])) }
        else if event == "release" {
            guard let id = inputSessionID else { throw Invalid() }
            if persistent || session?.geometry.usesList == true { pointerUp(at: try point(request["point"]), sessionID: id) } else { release(sessionID: id) }
        } else if event == "cancel" { session?.pointerCancelled() }
        else if event == "key" {
            let keys: [String: RadialKey] = ["tab": .tab, "left": .left, "right": .right, "up": .up, "down": .down, "enter": .enter, "space": .space, "escape": .escape, "backspace": .backspace]
            guard let name = request["key"] as? String, let key = keys[name], let id = inputSessionID else { throw Invalid() }
            self.key(key, modifiers: [], sessionID: id)
        } else if event != "state" { throw Invalid() }
        if let level = request["level"] as? String, level != "root", session?.group != level {
            guard let index = session?.root.firstIndex(where: { $0.group == level }) else { throw Invalid() }
            session?.back(); _ = session?.activate(index)
        } else if request["level"] as? String == "root", session?.group != nil { session?.back() }
        if let id = request["highlighted"] as? String {
            guard let index = session?.items.firstIndex(where: { $0.id == id }) else { throw Invalid() }
            session?.inspect(index, keyboard: request["keyboard"] as? Bool ?? false)
        }
        if session?.closed == true { close() } else { update() }
        if let path = request["snapshot"] as? String, !snapshot(to: path) { throw Invalid() }
    }
}
