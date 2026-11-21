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
    private let inputTap: InputTap
    private let toolbar = Toolbar()
    private var pendingControlTool = false
    var controlsState: PresentationControlsState {
        PresentationControlsState(mode: mode, tool: Preferences.drawingTool, pointerVisible: isActive,
                                  drawingAllowed: drawingAllowed, capturing: isCapturing, pendingDrawing: pendingControlTool)
    }
    func chooseToolFromControls(_ tool: DrawingTool) {
        guard !isCapturing else { return }
        if !drawingAllowed {
            pendingControlTool = true; Preferences.drawingTool = tool
            toolbar.setMode(mode, pending: true); toolbar.setNeedsPermission(true)
            onActiveChanged?(); return
        }
        if !chooseTool(tool) {
            pendingControlTool = true; Preferences.drawingTool = tool
            toolbar.setMode(mode, pending: true); toolbar.setNeedsPermission(true); onActiveChanged?()
        }
    }
    func verifyToolbar(_ request: [String: Any]) -> [String: Any] { toolbar.verify(request) }
    func requestDrawingPermission() { onNeedsPermission?() }
    func showAllPointersFromControls() { pointerBrowser.show(restoration: nil) }

    private let screenshotResult = ScreenshotResult()
    private let screenshotSelection = ScreenshotSelection()
    let radial: RadialMenu
    let pointerBrowser: PointerBrowser
    let clearRecovery: ClearRecovery
    let commandError = QuickCommandError()
    private var quickCaptureRequested = false
    private var browserHandoff: Task<Void, Never>?
    private var browserRestoration: QuickControlsFocusRestoration?
    private var quickClearBounds: CGRect?
    private(set) var captureExclusion = CaptureExclusionState()
    var captureDiagnostics: [String: Any] { ["phase": captureExclusion.phase.rawValue, "excludedWindows": captureExclusion.windowIDs, "wheelVisible": radial.visible, "browserVisible": pointerBrowser.visible, "resultVisible": screenshotResult.window?.isVisible ?? false, "recovery": clearRecovery.diagnostics] }

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
    private let menuWindows: () -> [CGRect]
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
    var isSelectingScreenshotRegion: Bool { screenshotSelection.isVisible }
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
    var inkStrokes: Int { isActive ? armView.ink.count : 0 }
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
         magnifier: MagnifierController = MagnifierController(),
         quickControlsFocus: QuickControlsFocus = .system,
         menuWindows: (() -> [CGRect])? = nil,
         inputTap: InputTap = InputTap()) {
        self.inputTap = inputTap
        self.menuWindows = menuWindows ?? Self.openMenus
        radial = RadialMenu(focus: quickControlsFocus)
        pointerBrowser = PointerBrowser(focus: quickControlsFocus)
        clearRecovery = ClearRecovery(focus: quickControlsFocus)
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
        inputTap.radial.onEvent = { [weak self] sessionID, event in
            guard let self else { return }
            switch event {
            case .open(let cg), .persistentOpen(let cg):
                guard self.inputTap.radial.currentSessionID == sessionID else { return }
                guard self.radialEligible else { self.inputTap.radial.end(sessionID: sessionID); return }
                let persistent: Bool
                if case .persistentOpen = event { persistent = true } else { persistent = false }
                self.radial.open(sessionID: sessionID, at: Self.appKitPoint(cg), style: self.style, mode: self.mode, canUndo: self.canUndo, canRedo: self.canRedo, hasInk: self.inkStrokes > 0, invocation: persistent ? .persistent : .held)
                self.updateToolbarVisibility()
            case .move(let cg): self.radial.move(to: Self.appKitPoint(cg), sessionID: sessionID)
            case .release: self.radial.release(sessionID: sessionID)
            case .click(let cg): self.radial.click(at: Self.appKitPoint(cg), sessionID: sessionID)
            case .cancel: self.radial.close(sessionID: sessionID)
            case .focusLost: self.radial.cancelForFocusLoss(sessionID: sessionID)
            case .key(let key, let modifiers): self.radial.key(key, modifiers: modifiers, sessionID: sessionID)
            case .pointerDown(let cg): self.radial.pointerDown(at: Self.appKitPoint(cg), sessionID: sessionID)
            case .pointerUp(let cg): self.radial.pointerUp(at: Self.appKitPoint(cg), sessionID: sessionID)
            case .pointerCancel: self.radial.pointerCancel(sessionID: sessionID)
            }
        }
        inputTap.onDismissControls = { [weak self] in self?.onDismissControls?() }
        inputTap.onControlStatusClick = { [weak self] in self?.onControlStatusClick?($0) }
        inputTap.onScreenLocked = { [weak self] in self?.stopForSystem("locked session input") }
        radial.onOpenBrowser = { [weak self] restoration in
            guard let self else { restoration?.restore(); return }
            self.openPointerBrowser(restoration: restoration)
        }
        radial.onWillPerform = { [weak self] operation, bounds in
            if operation == "clear" { self?.quickClearBounds = bounds }
            if operation == "capture" { self?.quickCaptureRequested = true }
        }
        radial.onFailure = { [weak self] failure in self?.quickCaptureRequested = false; self?.commandError.show(failure) }
        pointerBrowser.current = { [weak self] in self?.style ?? PointerStyle.saved }
        pointerBrowser.choose = { [weak self] id in
            let result = self?.radial.perform?(["version": 1, "operation": "style", "style": id])
            if case .failure(let failure) = result { self?.commandError.show(failure) }
            return result == .success
        }
        pointerBrowser.onVisibilityChanged = { [weak self] in self?.presentationContextChanged(); self?.syncInput() }
        clearRecovery.currentRevision = { [weak self] in self?.armView.ink.document.revision ?? UUID() }
        clearRecovery.onUndo = { [weak self] in self?.undo() }
        radial.annotationUndo.onUndo = { [weak self] in self?.undo() }
        radial.annotationUndo.onRedo = { [weak self] in self?.redo() }
        radial.annotationUndo.canUndo = { [weak self] in self?.radial.session != nil && self?.canUndo == true }
        radial.annotationUndo.canRedo = { [weak self] in self?.radial.session != nil && self?.canRedo == true }
        radial.annotationUndo.focusRecovery = { [weak self] in
            guard let self else { return false }
            return self.radial.focusRecovery(self.clearRecovery)
        }
        radial.onFocusOwnershipChanged = { [weak self] in self?.inputTap.radial.setKeyboardFocus($0) }
        clearRecovery.onContextChanged = { [weak self] in
            guard let self else { return }
            self.inputTap.radial.configureNativeSurface(region: self.clearRecovery.state.visible ? Self.cgRect(self.clearRecovery.window.frame) : nil, ownsFocus: self.clearRecovery.ownsKeyboardFocus)
            self.radial.cancelIfFocusLost()
            self.syncInput(); self.refreshShortcutContext()
        }
        radial.onClose = { [weak self] sessionID in self?.inputTap.radial.end(sessionID: sessionID); self?.updateToolbarVisibility() }
        radial.onVisibilityChanged = { [weak self] in
            guard let self else { return }
            self.inputTap.radial.setListMode(self.radial.session?.geometry.usesList ?? false)
            self.armView.pointerHidden = self.radial.visible
            if self.radial.usesSystemCursor || !self.isActive { CursorHider.show() }
            else if self.radial.visible { CursorHider.hide() }
            self.updateToolbarVisibility(); self.syncInput()
        }
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
        armView.annotations.onEdited = { [weak self] revision in self?.clearRecovery.documentChanged(to: revision) }
        armView.annotations.onChanged = { [weak self] in self?.annotationChanged() }
        displayLink.onFrame = { [weak self] in self?.tick() }
        toolbar.onPick = { [weak self] in self?.pick($0) }
        toolbar.onMode = { [weak self] in _ = self?.setMode($0) }
        toolbar.onTool = { [weak self] in self?.chooseToolFromControls($0) }
        toolbar.onAllPointers = { [weak self] in self?.showAllPointersFromControls() }
        toolbar.onRedo = { [weak self] in self?.redo() }
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
        inputTap.stop()
        catalogTimer?.invalidate()
        if let preferencesObserver { NotificationCenter.default.removeObserver(preferencesObserver) }
    }

    var drawingAllowed: Bool { accessibility() }
    var soundOn: Bool {
        get { Preferences.pointerConfiguration(for: style.rawValue).soundEnabled }
        set {
            do { try Preferences.updatePointer(style.rawValue) { $0.soundEnabled = newValue } }
            catch { Log.write("Unable to change pointer sound: \(error.localizedDescription)") }
        }
    }
    var soundAudible: Bool { soundOn && Preferences.soundOutput.audible }
    var soundStatus: String { Preferences.soundOutput.status(enabled: soundOn) }
    @discardableResult
    func pick(_ style: PointerStyle) -> Bool {
        guard (try? PointerCatalog.validateSelection(style)) != nil else { return false }
        cancelTapFeedback()
        cancelHandGestures()
        armView.setStyle(style)
        PointerStyle.saved = armView.style
        previousGestureSignature = HandGestureCatalog.signature(for: armView.style)
        toolbar.select(armView.style)
        pointerBrowser.refreshCurrent()
        syncSound()
        onActiveChanged?()
        return true
    }
    func cyclePointer(by delta: Int) {
        guard delta != 0 else { return }
        CustomHands.reload()
        guard let next = try? PointerCatalog.nextSelectable(after: style, direction: delta < 0 ? .backward : .forward) else { return }
        pick(next)
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
        pendingControlTool = false
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
    func clearInk() {
        let bounds = quickClearBounds; quickClearBounds = nil
        releaseDrawing()
        let before = armView.ink.document.revision
        armView.ink.clear()
        if let bounds, armView.ink.document.revision != before {
            let owner = armView.ink
            clearRecovery.currentRevision = { [weak owner] in owner?.document.revision ?? UUID() }
            clearRecovery.onUndo = { [weak self, weak owner] in self?.releaseDrawing(); owner?.undo() }
            clearRecovery.onRedo = { [weak self, weak owner] in self?.releaseDrawing(); owner?.redo() }
            clearRecovery.canRedo = { [weak owner] in owner?.canRedo ?? false }
            clearRecovery.show(revision: owner.document.revision, on: bounds)
        }
    }
    func openPointerBrowser(editing: Bool = false, restoration: QuickControlsFocusRestoration? = nil) {
        let restoration = restoration ?? radial.takeFocusRestoration()
        radial.closeImmediately(); browserHandoff?.cancel()
        // Pending replacements retain the first obligation, just like recovery.
        if browserRestoration == nil { browserRestoration = restoration }
        browserHandoff = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.inputTap.radial.hasOwnedInput {
                do { try await Task.sleep(nanoseconds: 20_000_000) } catch { return }
            }
            guard !Task.isCancelled else { return }
            guard !self.isCapturing else { self.cancelBrowserHandoff(); return }
            let restoration = self.browserRestoration
            self.browserRestoration = nil; self.browserHandoff = nil
            self.pointerBrowser.show(editing: editing, restoration: restoration)
        }
    }
    private func cancelBrowserHandoff() {
        browserHandoff?.cancel(); browserHandoff = nil
        let restoration = browserRestoration; browserRestoration = nil
        restoration?.restore()
    }
    func toggleToolbar() { Preferences.showToolbar.toggle() }
    @discardableResult func beginGesture(_ slot: HandGestureSlot, owner: String, shortcut: Shortcut? = nil) -> Bool {
        guard canUseHandGestures,
              !(0..<32).contains(where: { CGEventSource.buttonState(.hidSystemState, button: CGMouseButton(rawValue: UInt32($0))!) }),
              HandGestureCatalog.image(slot, style: style) != nil else { return false }
        gestures.begin(slot, owner: owner, shortcut: shortcut)
        applyGesture(); return true
    }
    func endGesture(_ owner: String, notify: Bool = true) { gestures.end(owner); applyGesture(notify: notify) }
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
    private func applyGesture(notify: Bool = true) {
        let previous = armView.activeGesture
        if !armView.setGesture(gestures.active) { gestures.cancel(); _ = armView.setGesture(nil) }
        if previous != armView.activeGesture && notify { onActiveChanged?() }
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
        if radial.visible { radial.refresh(style: PointerStyle.saved, mode: mode) }
        previousCatalog = PointerCatalog.entries
        if previousShowToolbar != Preferences.showToolbar {
            previousShowToolbar = Preferences.showToolbar
            revealUntil = Preferences.showToolbar ? Date().addingTimeInterval(3) : .distantPast
        }
        updateToolbarVisibility()
        armView.updateInkColor()
        if armView.style != PointerStyle.saved { cancelTapFeedback(); armView.setStyle(PointerStyle.saved) }
        toolbar.select(armView.style)
        toolbar.setMode(mode, pending: pendingControlTool)
        toolbar.setMagnifying(isMagnifying)
        toolbar.setNeedsPermission(needsDrawingPermission || pendingControlTool)
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
        tapSound.load(Preferences.pointerConfiguration(for: style.rawValue).sound)
        tapSound.setOutput(Preferences.soundOutput)
        if !soundAudible { contactFeedback.cancel() }
        tapSound.enabled = soundOn
        toolbar.setSoundOn(soundAudible, status: soundStatus)
        onSoundChanged?()
    }
    private func annotationChanged() {
        toolbar.setUndoEnabled(canUndo)
        toolbar.setRedoEnabled(canRedo)
        toolbar.setClearEnabled(inkStrokes > 0)
        radial.updateHistory(canUndo: canUndo, canRedo: canRedo, hasInk: inkStrokes > 0)
        onActiveChanged?()
    }
    private var radialEligible: Bool {
        isActive && accessibility() && !ownMenuOpen && !textEditor.isShowing && !isCapturing
            && (NSApp.keyWindow == nil || NSApp.keyWindow === radial.window || (radial.visible && NSApp.keyWindow === clearRecovery.window)) && Date() >= menuOpeningUntil && menuRects.isEmpty
    }
    @discardableResult func openQuickControls() -> Bool {
        guard accessibility() else { onNeedsPermission?(); return false }
        guard radialEligible, !radial.visible else { return false }
        inputTap.configureRadial(trigger: Preferences.radialTrigger, eligible: true)
        return inputTap.openQuickControls(at: Self.cgPoint(NSEvent.mouseLocation), onConnectionFailure: { [weak self] in self?.onNeedsPermission?() }) != nil
    }
    private func syncInput() {
        radial.cancelIfFocusLost()
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
        armView.annotations.activate()
        tapSound.warm()
        syncInput()
        installMonitors()
        CursorHider.hide()
        rejoinPresentationWindows()
        window.orderFrontRegardless()
        revealUntil = Date().addingTimeInterval(3)
        lastMotion = Date()
        tick()
        toolbar.setNeedsPermission(needsDrawingPermission || pendingControlTool)
        updateToolbarVisibility()
        scheduleMotion()
        refreshShortcutContext()
        onActiveChanged?()
        return true
    }
    func toggle() { if isActive { deactivate() } else { _ = activate() } }
    func exit() { deactivate() }
    func deactivate() {
        cancelBrowserHandoff()
        if captureExclusion.phase == .hidden || captureExclusion.phase == .ready { finishCaptureExclusion() }
        pointerBrowser.close()
        screenshotSelection.cancel()
        screenshotResult.close()
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
        armView.annotations.deactivate()
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
        radial.cancelForFocusLoss()
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
        releaseDrawing(); radial.cancelForFocusLoss(); onDismissControls?()
        rejoinPresentationWindows()
        window.orderFrontRegardless()
        updateToolbarVisibility()
        wake()
    }

    private func pressed(_ button: Int64, feedback: InputTap.Feedback, at cgPoint: CGPoint, flags: CGEventFlags) {
        guard isActive else { return }
        tick() // Reconcile the display before interpreting display-local annotation input.
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

    func captureRegion() {
        guard !isCapturing, !screenshotSelection.isVisible, let screen = currentScreen() else { return }
        screenshotResult.close()
        releaseDrawing()
        radial.close()
        screenshotSelection.show(on: screen) { [weak self] rect in
            guard let self else { return }
            self.presentationContextChanged()
            if let rect { self.captureScreenshot(fromToolbar: true, region: rect, screen: screen) }
        }
        presentationContextChanged()
    }

    func captureScreenshot(fromToolbar: Bool = false, region: CGRect? = nil, screen selectedScreen: NSScreen? = nil) {
        let fromQuickControls = quickCaptureRequested; quickCaptureRequested = false
        guard !isCapturing, !screenshotSelection.isVisible else { return }
        screenshotResult.close()
        if !isActive { _ = activate() }
        guard let screen = selectedScreen ?? currentScreen() else { return }
        releaseDrawing()
        cancelTapFeedback()
        cancelHandGestures()
        isCapturing = true
        beginCaptureExclusion()
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
                    self.finishCaptureExclusion()
                    self.armView.pointerHidden = previousHidden
                    self.toolbar.setCapturing(false)
                    self.syncInput(); self.refreshShortcutContext()
                    if self.isActive { self.wake() }
                }
            }
            do {
                try await Task.sleep(nanoseconds: 80_000_000)
                self.captureExclusion.compositorDrained()
                guard self.captureExclusion.canCapture else { throw ScreenshotError.encoding }
                let captured = try await ScreenCapture().screenshot(screen: screen, overlayID: CGWindowID(self.window.windowNumber), excluding: self.captureExclusion.windowIDs)
                let image: CGImage
                if let region {
                    guard let pixels = ScreenshotRegion.pixels(for: region, on: screen.frame,
                                                               imageSize: CGSize(width: captured.width, height: captured.height)),
                          let crop = captured.cropping(to: pixels) else { throw ScreenshotError.encoding }
                    image = crop
                } else { image = captured }
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
                self.screenshotResult.show(png: data, destination: destination, copied: copies, on: screen)
            } catch is CancellationError {
                return
            } catch {
                self.lastCaptureError = error.localizedDescription
                if fromQuickControls { self.commandError.show(.capture(error), on: screen.visibleFrame) }
                else { self.screenshotResult.show(error: error, on: screen) { [weak self] in
                    if ScreenshotRecovery.action(for: error) == .permissionSettings { ScreenCapture.openPermissionSettings() }
                    else { self?.captureScreenshot(fromToolbar: fromToolbar, region: region, screen: screen) }
                } }
            }
        }
    }

    func retryQuickControlsScreenshot() { quickCaptureRequested = true; captureScreenshot() }

    func seedClearRecovery() {
        armView.ink.addText("Quick controls recovery fixture", at: CGPoint(x: 100, y: 100), width: 4)
        quickClearBounds = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1200, height: 800)
        clearInk()
    }
    func verificationDocumentEdit() { armView.ink.addText("Later edit", at: CGPoint(x: 120, y: 120), width: 4) }

    func beginCaptureExclusion() {
        toolbar.hide()
        cancelBrowserHandoff()
        inputTap.radial.setCaptureSuspended(true)
        let windows = [radial.window, pointerBrowser.window, clearRecovery.window, commandError.window] + [screenshotResult.window].compactMap { $0 }
        captureExclusion.begin(windowIDs: windows.map { CGWindowID($0.windowNumber) })
        radial.closeImmediately(); pointerBrowser.close()
        screenshotResult.close(); commandError.dismiss(); clearRecovery.hideForCapture(true)
    }
    func finishCaptureExclusion() {
        captureExclusion.finish()
        inputTap.radial.setCaptureSuspended(false)
        clearRecovery.documentChanged(to: clearRecovery.currentRevision()); clearRecovery.hideForCapture(false)
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
        if event.type == .keyDown && event.keyCode == 53 {
            cancelHandGestures()
            if canUseDrawingShortcuts, armView.ink.isDrawing {
                armView.ink.cancel()
                downPoint = nil; buttonSeenDown = false
            }
        }
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
            guard let self, self.isActive, self.style == style, self.soundAudible else { return }
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
        let display = DisplayInkStore.Display(screen)
        if currentFrame != screen.frame || armView.annotations.display != display {
            let moved = currentFrame != nil
            if moved { cancelTapFeedback(); cancelHandGestures(); releaseDrawing(); textEditor.cancel() }
            if let display { armView.annotations.select(display) }
            armView.updateInkColor()
            annotationChanged()
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
        toolbar.setRevealed(isActive && Preferences.showToolbar && !isCapturing && !radial.visible && !armView.ink.isDrawing
                            && toolbar.wantsReveal(mouse: mouse, deadline: revealUntil))
    }

    private func updateZones(mouse: CGPoint, screen: NSScreen) {
        let f = toolbar.frame
        updateToolbarVisibility(mouse: mouse)
        if Date().timeIntervalSince(lastMenuScan) > (Date() < menuOpeningUntil ? 0.03 : 0.1) {
            lastMenuScan = Date()
            menuRects = menuWindows()
        }
        let menuBar = Self.menuBarRect(screen)
        let overMenu = menuBar.contains(mouse) || menuRects.contains { $0.contains(Self.cgPoint(mouse)) } || ownMenuOpen
        let ownFrames = NSApp.windows.filter { $0.isVisible && $0 !== window && $0 !== radial.window && !toolbar.windows.contains($0) }.map(\.frame)
        let overOwnWindow = ownFrames.contains { $0.contains(mouse) }
        let pressing = (0..<32).contains { CGEventSource.buttonState(.hidSystemState, button: CGMouseButton(rawValue: UInt32($0))!) }
        let normal = radial.usesSystemCursor || (!radial.visible && (overMenu || overOwnWindow || textEditor.isShowing
            || mode.hidesPointer(whilePressing: pressing, keepsHand: Preferences.interactKeepsHand)))
        if normal != normalCursor && !isCapturing {
            if normal {
                if overMenu || overOwnWindow || textEditor.isShowing { cancelTapFeedback() }
                else { contactFeedback.cancel(); armView.cancelTapAnimation() }
                cancelHandGestures()
            }
            normalCursor = normal
            armView.pointerHidden = normal || radial.visible
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
            toolbar.showMessage("Drawing access changed. Cursor is selected so you can use apps normally.")
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
