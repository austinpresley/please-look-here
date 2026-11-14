import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class OverlayController {
    private final class OverlayWindow: NSWindow {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
    private let window: OverlayWindow
    private let armView: ArmView
    private let inputTap = InputTap()
    private let toolbar = Toolbar()
    let radial = RadialMenu()
    private let accessibility: () -> Bool
    private let screenRecording: () -> Bool
    private let requestRecording: () -> Void
    private let magnifier: MagnifierController
    private let tapSound: TapSound
    private let contactFeedback = TapContactFeedback()
    private var previousTapSwing = Preferences.tapSwing
    private var previousPointerMode = Preferences.pointerMode
    private var gestures = HandGestureSession()
    private let gesturePreview = TapContactFeedback()
    private var pendingGesturePreview: HandGestureSlot?
    private var gesturePreviewDeadline = Date.distantPast
    private var previousGestureSignature = ""
    var activeGesture: HandGestureSlot? { armView.activeGesture }
    var canUseHandGestures: Bool { canUsePresentationShortcuts && !radial.visible && !armView.held && style.assetName != nil }
    private let displayLink = PointerDisplayLink()
    private let textEditor = TextAnnotationEditor()
    private var lifecycle: PresentationLifecycle?
    private var timer: Timer?
    private var timerInterval: TimeInterval = 0
    private var monitors: [Any] = []
    private var currentFrame: CGRect?
    private var heldButtons = Set<Int64>()
    private var downPoint: CGPoint?
    private var buttonSeenDown = false
    private var lastMouse: CGPoint?
    private var lastMotion = Date()
    private var lastService = Date.distantPast
    private var lastPermissionCheck = Date.distantPast
    private var normalCursor = false
    private var ownMenuOpen = false
    private var menuRects: [CGRect] = []
    private var menuOpeningUntil = Date.distantPast
    private var lastMenuScan = Date.distantPast
    private var revealUntil = Date.distantPast
    private var previousShowToolbar = Preferences.showToolbar
    private var needsDrawingPermission = false
    private var desiredDrawInput = false
    private var shortcutContext = ""
    private var captureTask: Task<Void, Never>?
    private var captureID: UUID?
    private var preferencesObserver: Any?
    private var catalogTimer: Timer?
    private var previousCatalog: [PointerCatalog.Entry] = []
    private(set) var isActive = false
    private(set) var isCapturing = false
    private(set) var isMagnifying = false
    private(set) var lastMagnifierError: String?
    var magnifierDiagnostics: [String: Any] { magnifier.diagnostics }
    private(set) var lastCaptureURL: URL?
    private(set) var lastCaptureError: String?
    private(set) var lastCaptureSize: [Int] = []
    var onActiveChanged: (() -> Void)?
    var onSoundChanged: (() -> Void)?
    var onNeedsPermission: (() -> Void)?
    var onShortcutContextChanged: (() -> Void)?
    var onDismissControls: (() -> Void)?
    var onControlStatusClick: ((Bool) -> Void)?
    func presentControls(_ open: Bool, nativeMenu: Bool, regions: [CGRect]) {
        suspendInput(open)
        inputTap.configureControls(open: open && accessibility(), nativeMenu: nativeMenu, regions: regions.map(Self.cgRect))
    }
    var extraPassThrough: (() -> [CGRect])?

    var mode: PointerMode { Preferences.pointerMode }
    var style: PointerStyle { armView.style }
    var canUndo: Bool { armView.ink.canUndo }
    var canRedo: Bool { armView.ink.canRedo }
    var inkStrokes: Int { armView.ink.count }
    var tapMaxWaitMs: Double { inputTap.maxWaitMs }
    var motionClock: String { displayLink.isRunning ? "displayLink" : timer == nil ? "sleeping" : "timer" }
    var inputDiagnostics: [String: Any] { inputTap.diagnostics }
    var toolbarVisible: Bool { toolbar.revealed }
    var toolbarFrame: CGRect { toolbar.frame }
    var pointerVisible: Bool { isActive && !armView.pointerHidden }
    var onActiveSpace: Bool { window.isOnActiveSpace }
    var shadowDiagnostics: [String: Any] { armView.shadowDiagnostics }
    var contactSoundPending: Bool { contactFeedback.pending }
    var canUsePresentationShortcuts: Bool {
        isActive && !ownMenuOpen && !textEditor.isShowing && !isCapturing && NSApp.keyWindow == nil && Date() >= menuOpeningUntil && menuRects.isEmpty
    }
    var canUseDrawingShortcuts: Bool { canUsePresentationShortcuts && mode == .draw }
    var windowsForTesting: [NSWindow] { [window] + toolbar.windows + [radial.window] }
    var debugState: String {
        "active=\(isActive) mode=\(mode.rawValue) tool=\(Preferences.drawingTool.rawValue) held=\(armView.held) downPoint=\(downPoint != nil) drawing=\(armView.ink.isDrawing) strokes=\(inkStrokes) motion=\(Preferences.pointerMotion.rawValue) clock=\(motionClock)"
    }

    init(accessibility: @escaping () -> Bool = { AXIsProcessTrusted() },
         screenRecording: @escaping () -> Bool = { ScreenCapture.hasPermission },
         requestRecording: @escaping () -> Void = { ScreenCapture.requestPermission() },
         tapSound: TapSound = TapSound(),
         magnifier: MagnifierController = MagnifierController()) {
        self.accessibility = accessibility
        self.screenRecording = screenRecording
        self.requestRecording = requestRecording
        self.tapSound = tapSound
        self.magnifier = magnifier
        let frame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        window = OverlayWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
        window.ignoresMouseEvents = true; window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        armView = ArmView(frame: CGRect(origin: .zero, size: frame.size))
        window.contentView = armView
        armView.installMagnifier(magnifier.layer)
        magnifier.onFailure = { [weak self] message in
            guard let self else { return }
            self.isMagnifying = false; self.lastMagnifierError = message
            self.toolbar.setMagnifying(false); self.toolbar.showMessage(message)
            self.onActiveChanged?()
        }
        inputTap.radial.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .open(let cg):
                guard self.radialEligible else { self.inputTap.radial.end(); return }
                self.radial.open(at: Self.appKitPoint(cg), style: self.style, mode: self.mode, canUndo: self.canUndo, canRedo: self.canRedo, hasInk: self.inkStrokes > 0)
                self.updateToolbarVisibility()
            case .move(let cg): self.radial.move(to: Self.appKitPoint(cg))
            case .release: self.radial.release()
            case .click(let cg): self.radial.click(at: Self.appKitPoint(cg))
            case .cancel: self.radial.close()
            }
        }
        inputTap.onDismissControls = { [weak self] in self?.onDismissControls?() }
        inputTap.onControlStatusClick = { [weak self] in self?.onControlStatusClick?($0) }
        inputTap.onScreenLocked = { [weak self] in self?.stopForSystem("locked session input") }
        radial.onClose = { [weak self] in self?.inputTap.radial.end(); self?.updateToolbarVisibility() }
        inputTap.onMouseDown = { [weak self] button, feedback, point, flags in self?.pressed(button, feedback: feedback, at: point, flags: flags) }
        inputTap.onMouseUp = { [weak self] button, feedback in self?.released(button, feedback: feedback) }
        inputTap.onLeftDragged = { [weak self] point in self?.dragged(to: point) }
        inputTap.onPassThroughPress = { [weak self] point in
            guard let self = self else { return }
            if let screen = self.currentScreen(), Self.cgRect(Self.menuBarRect(screen)).contains(point) {
                self.menuOpeningUntil = Date().addingTimeInterval(1)
                self.inputTap.setActive(false)
            }
            self.wake()
        }
        armView.ink.onChanged = { [weak self] in self?.annotationChanged() }
        displayLink.onFrame = { [weak self] in self?.tick() }
        toolbar.onPick = { [weak self] in self?.pick($0) }
        toolbar.onMode = { [weak self] in _ = self?.setMode($0) }
        toolbar.onTool = { [weak self] in _ = self?.chooseTool($0) }
        toolbar.onUndo = { [weak self] in self?.undo() }
        toolbar.onClear = { [weak self] in self?.clearInk() }
        toolbar.onCapture = { [weak self] in self?.captureScreenshot(fromToolbar: true) }
        toolbar.onMagnifier = { [weak self] in guard let self else { return }; _ = self.setMagnification(!self.isMagnifying) }
        toolbar.onToggleSound = { [weak self] in self?.soundOn.toggle() }
        toolbar.onExit = { [weak self] in self?.exit() }
        toolbar.onFixPermission = { [weak self] in self?.onNeedsPermission?() }
        preferencesObserver = NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [weak self] _ in self?.syncPreferences() }
        syncPreferences()
        lifecycle = PresentationLifecycle(stop: { [weak self] in self?.stopForSystem($0) },
                                          recover: { [weak self] in self?.recoverPresentation() },
                                          accessibilityChanged: { [weak self] in self?.cancelTapFeedback(); self?.cancelHandGestures(); self?.wake() })
        catalogTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            CustomHands.reload()
            if self.previousCatalog != PointerCatalog.entries { self.syncPreferences() }
            let gestureSignature = HandGestureCatalog.signature(for: self.style)
            if self.previousGestureSignature != gestureSignature {
                self.previousGestureSignature = gestureSignature
                self.cancelHandGestures(notify: false)
                self.onShortcutContextChanged?()
                self.onActiveChanged?()
            }
            // A sleeping pointer still notices permissions, app windows and menus
            // at low frequency. This service does not restart motion rendering.
            if self.isActive, let screen = self.currentScreen() {
                self.updateZones(mouse: NSEvent.mouseLocation, screen: screen)
                self.checkPermission(); self.refreshShortcutContext(); self.refreshMagnifier()
            }
        }
        catalogTimer?.tolerance = 0.25
    }

    deinit {
        catalogTimer?.invalidate()
        if let preferencesObserver { NotificationCenter.default.removeObserver(preferencesObserver) }
    }

    var drawingAllowed: Bool { accessibility() }
    var soundOn: Bool {
        get { style == .laser ? Preferences.laserSound : Preferences.handSound }
        set {
            if style == .laser { Preferences.laserSound = newValue } else { Preferences.handSound = newValue }
        }
    }
    @discardableResult
    func pick(_ style: PointerStyle) -> Bool {
        guard (try? PointerCatalog.validateSelection(style)) != nil else { return false }
        cancelTapFeedback()
        cancelHandGestures()
        armView.setStyle(style)
        PointerStyle.saved = armView.style
        previousGestureSignature = HandGestureCatalog.signature(for: armView.style)
        toolbar.select(armView.style)
        syncSound()
        onActiveChanged?()
        return true
    }
    func cyclePointer(by delta: Int) {
        let pinned = PointerCatalog.quickStyles
        guard !pinned.isEmpty else { return }
        let index = pinned.firstIndex(of: style) ?? 0
        pick(pinned[min(max(index + delta, 0), pinned.count - 1)])
    }
    @discardableResult
    func setMode(_ requested: PointerMode) -> Bool {
        guard !isCapturing else { return false }
        if requested == .draw && (!accessibility() || !inputTap.install()) {
            needsDrawingPermission = true
            if Preferences.pointerMode != .point { Preferences.pointerMode = .point }
            toolbar.setMode(.point)
            toolbar.setNeedsPermission(true)
            updateToolbarVisibility()
            onNeedsPermission?()
            return false
        }
        inputTap.setActive(false)
        cancelTapFeedback()
        cancelHandGestures()
        releaseDrawing()
        heldButtons.removeAll()
        armView.held = false
        if Preferences.pointerMode != requested { Preferences.pointerMode = requested }
        needsDrawingPermission = false
        toolbar.setNeedsPermission(false)
        toolbar.setMode(requested)
        syncInput()
        refreshShortcutContext()
        onActiveChanged?()
        return true
    }
    @discardableResult
    func chooseTool(_ tool: DrawingTool) -> Bool {
        guard setMode(.draw) else { return false }
        Preferences.drawingTool = tool
        return true
    }
    func toggleMode() { _ = setMode(mode == .point ? .draw : .point) }
    func undo() { releaseDrawing(); armView.ink.undo() }
    func redo() { releaseDrawing(); armView.ink.redo() }
    func clearInk() { releaseDrawing(); armView.ink.clear() }
    func toggleToolbar() { Preferences.showToolbar.toggle() }
    @discardableResult func beginGesture(_ slot: HandGestureSlot, owner: String, shortcut: Shortcut? = nil) -> Bool {
        guard canUseHandGestures,
              !(0..<32).contains(where: { CGEventSource.buttonState(.hidSystemState, button: CGMouseButton(rawValue: UInt32($0))!) }),
              HandGestureCatalog.image(slot, style: style) != nil else { return false }
        gestures.begin(slot, owner: owner, shortcut: shortcut)
        applyGesture(); return true
    }
    func endGesture(_ owner: String) { gestures.end(owner); applyGesture() }
    func cancelHandGestures(notify: Bool = true) {
        let hadGesture = activeGesture != nil
        gestures.cancel(); gesturePreview.cancel(); pendingGesturePreview = nil
        _ = armView.setGesture(nil)
        if hadGesture && notify { onActiveChanged?() }
    }
    @discardableResult func previewGesture(_ slot: HandGestureSlot) -> Bool {
        guard !isCapturing && NSApp.keyWindow == nil && style.assetName != nil,
              HandGestureCatalog.image(slot, style: style) != nil else { return false }
        if !isActive && !activate() { return false }
        cancelHandGestures(notify: false)
        pendingGesturePreview = slot; gesturePreviewDeadline = Date().addingTimeInterval(2)
        wake(); return true
    }
    private func applyGesture() {
        let previous = armView.activeGesture
        if !armView.setGesture(gestures.active) { gestures.cancel(); _ = armView.setGesture(nil) }
        if previous != armView.activeGesture { onActiveChanged?() }
    }
    private func refreshGestures() {
        if pendingGesturePreview != nil && Date() > gesturePreviewDeadline { pendingGesturePreview = nil }
        guard canUseHandGestures else {
            if activeGesture != nil { cancelHandGestures(notify: false) }
            return
        }
        if let slot = pendingGesturePreview {
            pendingGesturePreview = nil
            if beginGesture(slot, owner: "preview") {
                gesturePreview.schedule(after: 2) { [weak self] in self?.endGesture("preview") }
            }
        }
    }
    func presentationContextChanged() {
        if NSApp.keyWindow != nil { cancelTapFeedback(); cancelHandGestures() }
        refreshMagnifier(); refreshShortcutContext()
    }
    func snapshotPresentation(to url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let image = try await ScreenCapture.ownWindowImage(self.window)
                try ScreenCapture.png(image).write(to: url, options: .atomic)
            } catch { try? error.localizedDescription.write(to: url.appendingPathExtension("error.txt"), atomically: true, encoding: .utf8) }
        }
    }
    @discardableResult func setMagnification(_ enabled: Bool) -> Bool {
        guard !enabled || !isCapturing else { return false }
        if enabled && !screenRecording() {
            lastMagnifierError = "Allow Screen Recording in Settings > General, then try magnification again."
            onDismissControls?(); deactivate()
            if ProcessInfo.processInfo.environment["TINYHAND_TEST_MODE"] != "1" { requestRecording() }
            return false
        }
        if enabled && !isActive && !activate() { return false }
        isMagnifying = enabled; lastMagnifierError = nil
        toolbar.setMagnifying(enabled)
        refreshMagnifier()
        if isActive { wake() }
        onActiveChanged?()
        return true
    }
    func resetTapWait() { inputTap.resetWait() }
    func toolbarButtonCenter(_ style: PointerStyle) -> CGPoint? { toolbar.center(of: style) }

    private func syncPreferences() {
        if previousPointerMode != mode {
            previousPointerMode = mode
            cancelTapFeedback()
        }
        cancelHandGestures(notify: false)
        previousGestureSignature = HandGestureCatalog.signature(for: PointerStyle.saved)
        if previousTapSwing != Preferences.tapSwing {
            previousTapSwing = Preferences.tapSwing
            cancelTapFeedback()
        }
        PointerCatalog.reconcile()
        if radial.visible { radial.close() }
        previousCatalog = PointerCatalog.entries
        if previousShowToolbar != Preferences.showToolbar {
            previousShowToolbar = Preferences.showToolbar
            revealUntil = Preferences.showToolbar ? Date().addingTimeInterval(3) : .distantPast
        }
        updateToolbarVisibility()
        armView.updateInkColor()
        if armView.style != PointerStyle.saved { cancelTapFeedback(); armView.setStyle(PointerStyle.saved) }
        toolbar.select(armView.style)
        toolbar.setMode(mode)
        toolbar.setMagnifying(isMagnifying)
        toolbar.setNeedsPermission(needsDrawingPermission)
        tapSound.load(Preferences.tapSound)
        syncSound()
        if isActive {
            if mode == .draw && !accessibility() {
                needsDrawingPermission = true
                Preferences.pointerMode = .point
                return
            }
            syncInput()
            scheduleMotion()
            tick()
        }
        refreshShortcutContext()
        onActiveChanged?()
    }
    private func syncSound() {
        if !soundOn { contactFeedback.cancel() }
        tapSound.enabled = soundOn
        toolbar.setSoundOn(soundOn)
        onSoundChanged?()
    }
    private func annotationChanged() {
        toolbar.setUndoEnabled(canUndo)
        onActiveChanged?()
    }
    private var radialEligible: Bool {
        isActive && accessibility() && !ownMenuOpen && !textEditor.isShowing && !isCapturing
            && NSApp.keyWindow == nil && Date() >= menuOpeningUntil && menuRects.isEmpty
    }
    private func syncInput() {
        inputTap.configureRadial(trigger: Preferences.radialTrigger, eligible: radialEligible)
        let enabled = isActive && mode == .draw && !ownMenuOpen && !textEditor.isShowing && !isCapturing
            && NSApp.keyWindow == nil && Date() >= menuOpeningUntil
        if desiredDrawInput && !enabled { releaseDrawing(); heldButtons.removeAll(); armView.held = false }
        desiredDrawInput = enabled
        inputTap.setActive(enabled)
    }
    func suspendInput(_ suspended: Bool) {
        if suspended { cancelTapFeedback(); cancelHandGestures() }
        ownMenuOpen = suspended
        if !suspended { menuOpeningUntil = .distantPast; lastMenuScan = .distantPast }
        syncInput()
        refreshShortcutContext()
        refreshMagnifier()
    }

    @discardableResult
    func activate() -> Bool {
        guard !PresentationSession.isLocked else { return false }
        guard !isActive else { return mode != .draw || inputTap.isInstalled }
        if mode == .draw, !accessibility() {
            Preferences.pointerMode = .point
            needsDrawingPermission = true
        }
        if mode == .draw, !inputTap.install() {
            Preferences.pointerMode = .point
            needsDrawingPermission = true
        }
        isActive = true
        currentFrame = nil
        tapSound.warm()
        syncInput()
        installMonitors()
        CursorHider.hide()
        rejoinPresentationWindows()
        window.orderFrontRegardless()
        revealUntil = Date().addingTimeInterval(3)
        lastMotion = Date()
        tick()
        toolbar.setNeedsPermission(needsDrawingPermission)
        updateToolbarVisibility()
        scheduleMotion()
        refreshShortcutContext()
        onActiveChanged?()
        return true
    }
    func toggle() { if isActive { deactivate() } else { _ = activate() } }
    func exit() { deactivate() }
    func deactivate() {
        guard isActive else { return }
        isActive = false
        cancelTapFeedback()
        cancelHandGestures(notify: false)
        isMagnifying = false; magnifier.suspend(); toolbar.setMagnifying(false)
        radial.close()
        inputTap.configureRadial(trigger: Preferences.radialTrigger, eligible: false)
        captureTask?.cancel()
        captureTask = nil
        captureID = nil
        isCapturing = false
        toolbar.setCapturing(false)
        textEditor.cancel()
        inputTap.setActive(false)
        timer?.invalidate(); timer = nil; timerInterval = 0
        displayLink.stop()
        monitors.forEach(NSEvent.removeMonitor); monitors.removeAll()
        heldButtons.removeAll()
        downPoint = nil
        armView.held = false
        armView.ink.reset()
        window.ignoresMouseEvents = true
        window.orderOut(nil)
        toolbar.hide()
        normalCursor = false
        armView.pointerHidden = false
        // The menu bar presentation owns its lease, independently of activation.
        inputTap.passThroughRects = []
        CursorHider.show()
        refreshShortcutContext()
        onActiveChanged?()
    }

    func stopForSystem(_ reason: String) {
        Log.write("Presentation stopped: \(reason)")
        onDismissControls?()
        deactivate()
        CursorHider.show()
    }
    private func rejoinPresentationWindows() {
        ([window] + toolbar.windows + [radial.window]).forEach { $0.rejoinAllSpaces() }
    }
    func recoverPresentation() {
        guard isActive else { return }
        cancelTapFeedback()
        cancelHandGestures()
        releaseDrawing(); radial.close(); onDismissControls?()
        rejoinPresentationWindows()
        window.orderFrontRegardless()
        updateToolbarVisibility()
        wake()
    }

    private func pressed(_ button: Int64, feedback: InputTap.Feedback, at cgPoint: CGPoint, flags: CGEventFlags) {
        guard isActive else { return }
        cancelHandGestures()
        heldButtons.insert(button)
        armView.press(); armView.held = true
        if feedback == .draw && button == 0 {
            let point = local(cgPoint)
            downPoint = point
            buttonSeenDown = false
            let tool: DrawingTool = flags.contains(.maskControl) ? .number : Preferences.drawingTool
            if tool == .text {
                downPoint = nil
                heldButtons.remove(button); armView.held = !heldButtons.isEmpty
                openText(at: point)
            } else {
                armView.ink.tool = tool
                armView.ink.begin(at: point, width: armView.inkWidth)
                scheduleTapSound()
            }
        }
        wake()
    }
    private func dragged(to point: CGPoint) {
        guard downPoint != nil else { return }
        armView.reachTapContact(); contactFeedback.reachContact()
        armView.ink.extend(to: local(point))
        wake()
    }
    private func released(_ button: Int64, feedback: InputTap.Feedback) {
        heldButtons.remove(button)
        if button == 0 && feedback == .draw { releaseDrawing() }
        armView.held = !heldButtons.isEmpty
        wake()
    }
    private func releaseDrawing() {
        if armView.ink.isDrawing { armView.ink.end() }
        downPoint = nil
        buttonSeenDown = false
        heldButtons.remove(0)
        armView.held = !heldButtons.isEmpty
        armView.ink.tool = Preferences.drawingTool
    }
    private func local(_ cg: CGPoint) -> CGPoint {
        let global = Self.appKitPoint(cg)
        let frame = currentFrame ?? window.frame
        return CGPoint(x: global.x - frame.minX, y: global.y - frame.minY)
    }
    private func openText(at point: CGPoint) {
        guard let frame = currentFrame else { return }
        textEditor.show(at: CGPoint(x: point.x + frame.minX, y: point.y + frame.minY)) { [weak self] text in
            guard let self = self else { return }
            if let text = text, self.isActive { self.armView.ink.addText(text, at: point, width: self.armView.inkWidth) }
            self.syncInput(); self.refreshShortcutContext(); self.wake()
        }
        syncInput()
        refreshShortcutContext()
    }

    func captureScreenshot(fromToolbar: Bool = false) {
        guard !isCapturing else { return }
        if !isActive { _ = activate() }
        guard let screen = currentScreen() else { return }
        releaseDrawing()
        cancelTapFeedback()
        cancelHandGestures()
        radial.close()
        isCapturing = true
        let captureID = UUID()
        self.captureID = captureID
        lastCaptureError = nil
        let copies = Preferences.captureCopies, saves = Preferences.captureSaves
        let folder = Preferences.captureFolder
        let previousHidden = armView.pointerHidden
        if fromToolbar { armView.pointerHidden = true }
        toolbar.setCapturing(true)
        refreshMagnifier()
        syncInput(); refreshShortcutContext()
        captureTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                if self.captureID == captureID {
                    self.captureID = nil
                    self.isCapturing = false
                    self.armView.pointerHidden = previousHidden
                    self.toolbar.setCapturing(false)
                    self.syncInput(); self.refreshShortcutContext()
                    if self.isActive { self.wake() }
                }
            }
            do {
                try await Task.sleep(nanoseconds: 50_000_000)
                let image = try await ScreenCapture().screenshot(screen: screen, overlayID: CGWindowID(self.window.windowNumber))
                try Task.checkCancellation()
                let data = try await Task.detached(priority: .userInitiated) { try ScreenCapture.png(image) }.value
                try Task.checkCancellation()
                var destination: URL?
                if saves || !copies {
                    destination = try await Task.detached(priority: .userInitiated) { try ScreenCapture.save(data, in: folder) }.value
                }
                try Task.checkCancellation()
                if copies {
                    guard ScreenCapture.copy(data) else { throw ScreenshotError.encoding }
                }
                self.lastCaptureURL = destination
                self.lastCaptureSize = [image.width, image.height]
                self.toolbar.showMessage(destination.map { "Screenshot saved: \($0.lastPathComponent)" } ?? "Screenshot copied to clipboard")
            } catch is CancellationError {
                return
            } catch {
                self.lastCaptureError = error.localizedDescription
                if ProcessInfo.processInfo.environment["TINYHAND_TEST_MODE"] == "1" {
                    self.toolbar.showMessage(error.localizedDescription)
                } else {
                    let wasVisible = self.window.isVisible
                    self.window.orderOut(nil)
                    let alert = NSAlert()
                    alert.messageText = "Screenshot could not be taken"
                    alert.informativeText = error.localizedDescription
                    alert.addButton(withTitle: "OK")
                    if error is ScreenshotError { alert.addButton(withTitle: "Open Screen Recording Settings") }
                    let response = alert.runModal()
                    if response == .alertSecondButtonReturn { ScreenCapture.openPermissionSettings() }
                    if wasVisible && self.isActive { self.window.orderFrontRegardless() }
                }
            }
        }
    }

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .flagsChanged, .keyDown, .keyUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in self?.observed(event, own: false) }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in self?.observed(event, own: true); return event }) { monitors.append(local) }
    }
    private func observed(_ event: NSEvent, own: Bool) {
        // A native drag can start in another app and end over our controls.
        // Local release still finishes its visual press and idle/gesture lease.
        if mode == .point && [.leftMouseUp, .rightMouseUp, .otherMouseUp].contains(event.type) { armView.held = false }
        if event.type == .flagsChanged { gestures.retainModifiers(event.modifierFlags); applyGesture() }
        if event.type == .keyUp { gestures.releaseKey(UInt32(event.keyCode)); applyGesture() }
        if event.type == .keyDown && event.keyCode == 53 { cancelHandGestures() }
        if mode == .point && !own && !isCapturing && !textEditor.isShowing {
            switch event.type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                cancelHandGestures()
                armView.press(); armView.held = true
                if !Preferences.interactKeepsHand { armView.cancelTapAnimation() }
                scheduleTapSound()
            case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
                armView.reachTapContact(); contactFeedback.reachContact()
            case .leftMouseUp, .rightMouseUp, .otherMouseUp: armView.held = false
            default: break
            }
        }
        wake()
    }
    #if DEBUG
    func observeForVerification(_ event: NSEvent, own: Bool) { observed(event, own: own) }
    func checkPermissionForVerification() { lastPermissionCheck = .distantPast; checkPermission() }
    #endif
    private func wake() {
        guard isActive else { return }
        lastMotion = Date()
        scheduleMotion()
        tick()
    }
    private func scheduleTapSound() {
        let style = self.style
        contactFeedback.schedule(after: armView.tapSoundDelay) { [weak self] in
            guard let self, self.isActive, self.style == style, self.soundOn else { return }
            self.tapSound.play()
        }
    }
    private func cancelTapFeedback() { contactFeedback.cancel(); armView.cancelTapAnimation(); tapSound.silence() }
    private func scheduleMotion() {
        guard isActive else { return }
        if MotionPacing.shouldSleep(stillFor: Date().timeIntervalSince(lastMotion),
            settling: armView.isSettling || CursorHider.isSettling, held: armView.held, drawing: armView.ink.isDrawing) {
            timer?.invalidate(); timer = nil; timerInterval = 0
            displayLink.stop()
            return
        }
        let busy = Date().timeIntervalSince(lastMotion) < 0.5 || armView.isSettling || armView.held || armView.ink.isDrawing
        if Preferences.pointerMotion == .responsive && busy && displayLink.start(on: armView) {
            runTimer(every: 1.0 / 30)
        } else {
            displayLink.stop()
            runTimer(every: busy ? 1.0 / 120 : 1.0 / 20)
        }
    }
    private func runTimer(every interval: TimeInterval) {
        guard timer == nil || abs(interval - timerInterval) > 0.0001 else { return }
        timer?.invalidate()
        timerInterval = interval
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tick(aim: !self.displayLink.isRunning)
        }
        if interval >= 1.0 / 20 { t.tolerance = interval * 0.5 }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    private func tick(aim: Bool = true) {
        guard isActive, let screen = currentScreen() else { return }
        let mouse = NSEvent.mouseLocation
        if currentFrame != screen.frame {
            let moved = currentFrame != nil
            if moved { cancelTapFeedback(); cancelHandGestures(); releaseDrawing(); armView.ink.reset() }
            currentFrame = screen.frame
            window.setFrame(screen.frame, display: false)
            armView.frame = CGRect(origin: .zero, size: screen.frame.size)
            toolbar.place(on: screen)
        }
        if mouse != lastMouse { lastMouse = mouse; lastMotion = Date() }
        if Date().timeIntervalSince(lastService) >= 1.0 / 30 {
            lastService = Date()
            updateZones(mouse: mouse, screen: screen)
            checkPermission()
            refreshShortcutContext()
        }
        if !isCapturing && aim {
            refreshGestures()
            armView.aim(cursor: CGPoint(x: mouse.x - screen.frame.minX, y: mouse.y - screen.frame.minY))
        }
        refreshMagnifier()
        if downPoint != nil {
            let down = CGEventSource.buttonState(.hidSystemState, button: .left)
            if down { buttonSeenDown = true }
            if buttonSeenDown && !down { releaseDrawing() }
        }
        scheduleMotion()
    }

    private func updateToolbarVisibility(mouse: CGPoint = NSEvent.mouseLocation) {
        let near = toolbar.frame.insetBy(dx: -48, dy: -32).contains(mouse)
        toolbar.setRevealed(isActive && Preferences.showToolbar && !radial.visible && !armView.ink.isDrawing
                            && (near || Date() < revealUntil))
    }

    private func updateZones(mouse: CGPoint, screen: NSScreen) {
        let f = toolbar.frame
        updateToolbarVisibility(mouse: mouse)
        if Date().timeIntervalSince(lastMenuScan) > (Date() < menuOpeningUntil ? 0.03 : 0.1) {
            lastMenuScan = Date()
            menuRects = Self.openMenus()
        }
        let menuBar = Self.menuBarRect(screen)
        let overMenu = menuBar.contains(mouse) || menuRects.contains { $0.contains(Self.cgPoint(mouse)) } || ownMenuOpen
        let ownFrames = NSApp.windows.filter { $0.isVisible && $0 !== window && $0 !== radial.window && !toolbar.windows.contains($0) }.map(\.frame)
        let overOwnWindow = ownFrames.contains { $0.contains(mouse) }
        let pressing = (0..<32).contains { CGEventSource.buttonState(.hidSystemState, button: CGMouseButton(rawValue: UInt32($0))!) }
        let normal = !radial.visible && (overMenu || overOwnWindow || textEditor.isShowing
            || mode.hidesPointer(whilePressing: pressing, keepsHand: Preferences.interactKeepsHand))
        if normal != normalCursor && !isCapturing {
            if normal {
                if overMenu || overOwnWindow || textEditor.isShowing { cancelTapFeedback() }
                else { contactFeedback.cancel(); armView.cancelTapAnimation() }
                cancelHandGestures()
            }
            normalCursor = normal
            armView.pointerHidden = normal
            if normal { CursorHider.show() } else { CursorHider.hide() }
        }
        let overDock = DockArea.contains(Self.cgPoint(mouse))
        let catchesDock = mode == .draw && inputTap.isInstalled && !normal
        window.ignoresMouseEvents = !(overDock && catchesDock)
        if !normal && !isCapturing { CursorHider.reassert(fighting: overDock, urgent: overMenu) }
        var rects = (extraPassThrough?() ?? []).map(Self.cgRect)
        rects += ownFrames.map(Self.cgRect)
        rects.append(Self.cgRect(menuBar))
        rects += menuRects
        if toolbar.revealed { rects.append(Self.cgRect(f)) }
        inputTap.passThroughRects = rects
        syncInput()
    }
    private func checkPermission() {
        guard Date().timeIntervalSince(lastPermissionCheck) > 1 else { return }
        lastPermissionCheck = Date()
        if isMagnifying && !screenRecording() {
            _ = setMagnification(false)
            lastMagnifierError = "Screen Recording access changed. Turn it on in Settings > General to use magnification."
            toolbar.showMessage(lastMagnifierError!)
        }
        if mode == .draw && !accessibility() {
            needsDrawingPermission = true
            releaseDrawing()
            Preferences.pointerMode = .point
            toolbar.setNeedsPermission(true)
            toolbar.showMessage("Drawing access changed. Interact stays on so you can use apps normally.")
        } else if needsDrawingPermission && accessibility() {
            needsDrawingPermission = false
            toolbar.setNeedsPermission(false)
        }
    }
    private func refreshShortcutContext() {
        let key = "\(canUsePresentationShortcuts)-\(canUseDrawingShortcuts)"
        guard key != shortcutContext else { return }
        if !canUsePresentationShortcuts { cancelTapFeedback() }
        shortcutContext = key
        onShortcutContextChanged?()
    }
    private func refreshMagnifier() {
        guard isActive && isMagnifying else { magnifier.suspend(); return }
        if isCapturing { magnifier.suspend(keepingImage: !armView.pointerHidden); return }
        guard !normalCursor && !ownMenuOpen && !textEditor.isShowing && !radial.visible,
              NSApp.keyWindow == nil, let screen = currentScreen(), let target = MagnifierTarget(screen) else {
            magnifier.suspend(); return
        }
        magnifier.update(target: target, mouse: NSEvent.mouseLocation,
                         zoom: CGFloat(Preferences.magnifierZoom), diameter: CGFloat(Preferences.magnifierDiameter))
    }
    private func currentScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main ?? NSScreen.screens.first
    }
    private static func menuBarRect(_ screen: NSScreen) -> CGRect {
        let height = max(24, screen.frame.maxY - screen.visibleFrame.maxY)
        return CGRect(x: screen.frame.minX, y: screen.frame.maxY - height, width: screen.frame.width, height: height)
    }
    private static func openMenus() -> [CGRect] {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return windows.compactMap {
            guard ($0[kCGWindowLayer as String] as? Int) == Int(CGWindowLevelForKey(.popUpMenuWindow)),
                  let bounds = $0[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: bounds as CFDictionary)
        }
    }
    private static func cgPoint(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: (NSScreen.screens.first?.frame.height ?? 0) - p.y) }
    private static func appKitPoint(_ p: CGPoint) -> CGPoint { cgPoint(p) }
    private static func cgRect(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: (NSScreen.screens.first?.frame.height ?? 0) - r.maxY, width: r.width, height: r.height)
    }
}
