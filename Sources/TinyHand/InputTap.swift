import AppKit

final class InputTap {
    /// Injectable connection operations keep opening/enable ordering testable
    /// without installing a system tap or requesting Accessibility.
    struct Installation {
        var install: () -> Bool
        var isEnabled: () -> Bool
        var setEnabled: (Bool) -> Void
    }
    private let lifecycleLock = NSRecursiveLock()
    private var nativeConnection: NativeConnection?
    private let sessionLocked: () -> Bool
    private let installation: Installation?
    private var connectionInstalled = false
    var onScreenLocked: (() -> Void)?
    init(sessionLocked: @escaping () -> Bool = { PresentationSession.isLocked }, radial: RadialInput = RadialInput(), installation: Installation? = nil) {
        self.sessionLocked = sessionLocked; self.radial = radial; self.installation = installation
    }
    private let controls = ControlInput()
    var onDismissControls: (() -> Void)?
    var onControlStatusClick: ((Bool) -> Void)?
    func configureControls(open: Bool, nativeMenu: Bool, regions: [CGRect]) {
        if open { _ = install() }
        lock.withLock {
            controls.configure(open: open, nativeMenu: nativeMenu, regions: regions)
            updateEnabled()
        }
    }
    let radial: RadialInput
    func configureRadial(trigger: RadialTrigger?, eligible: Bool) {
        radial.configure(trigger: trigger, eligible: eligible, flags: CGEventSource.flagsState(.combinedSessionState))
        if trigger != nil && eligible { _ = install() }
        lock.withLock { updateEnabled() }
    }
    @discardableResult func openQuickControls(at point: CGPoint, onConnectionFailure: () -> Void = {}) -> UInt? {
        guard install() else { onConnectionFailure(); return nil }
        let enabled = lock.withLock {
            openingQuickControls = true; updateEnabled()
            if !connectionEnabled { openingQuickControls = false; return false }
            return true
        }
        guard enabled else { onConnectionFailure(); return nil }
        // The connection is live before RadialInput can enqueue its open event.
        let id = radial.openPersistent(at: point)
        lock.withLock { openingQuickControls = false; updateEnabled() }
        return id
    }
    enum Feedback {
        case draw, interact
    }

    var onMouseDown: ((Int64, Feedback, CGPoint, CGEventFlags) -> Void)?
    var onMouseUp: ((Int64, Feedback) -> Void)?
    var onLeftDragged: ((CGPoint) -> Void)?
    var onPassThroughPress: ((CGPoint) -> Void)?
    private struct Press {
        let generation: UInt
    }

    private let lock = NSLock()
    private var active = false
    private var openingQuickControls = false
    private var generation: UInt = 0
    private var presses: [Int64: Press] = [:]
    private var _passThroughRects: [CGRect] = []
    private var _maxWaitMs: Double = 0
    private var eventCount = 0
    private var eventTypes: [String: Int] = [:]
    var diagnostics: [String: Any] {
        lock.withLock { ["installed": tap != nil || connectionInstalled, "enabled": connectionEnabled, "active": active, "events": eventCount, "types": eventTypes, "radial": radial.diagnostics, "controls": controls.diagnostics, "capturedButtons": presses.keys.sorted()] }
    }

    var passThroughRects: [CGRect] {
        get { lock.withLock { _passThroughRects } }
        set { lock.withLock { _passThroughRects = newValue } }
    }

    var maxWaitMs: Double { lock.withLock { _maxWaitMs } }
    private var tap: CFMachPort?
    var isInstalled: Bool { lock.withLock { tap != nil || connectionInstalled } }
    private var connectionEnabled: Bool { installation?.isEnabled() ?? tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    @discardableResult
    func install() -> Bool {
        lifecycleLock.lock(); defer { lifecycleLock.unlock() }
        guard !isInstalled else {
            return true
        }
        if let installation {
            guard installation.install() else { return false }
            lock.withLock { connectionInstalled = true; updateEnabled() }
            return true
        }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        let context = CallbackContext(owner: self)
        let refcon = Unmanaged.passRetained(context).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let context = Unmanaged<CallbackContext>.fromOpaque(refcon).takeUnretainedValue()
                guard let owner = context.owner else { return Unmanaged.passUnretained(event) }
                return owner.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            Unmanaged<CallbackContext>.fromOpaque(refcon).release()
            return false
        }
        CGEvent.tapEnable(tap: tap, enable: false)

        let connection = NativeConnection(tap: tap, context: refcon)
        connection.start()
        nativeConnection = connection
        lock.withLock { self.tap = tap; updateEnabled() }
        return true
    }

    /// Call while the owner is alive. Invalidation and callback drainage finish
    /// before returning; repeated stop calls are harmless and installation may restart.
    func stop() {
        lifecycleLock.lock(); defer { lifecycleLock.unlock() }
        lock.withLock {
            active = false; openingQuickControls = false; generation &+= 1
            if let installation, connectionInstalled { installation.setEnabled(false) }
            connectionInstalled = false
            if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
            tap = nil
        }
        let connection = nativeConnection
        nativeConnection = nil
        connection?.stop()
    }

    deinit { stop() }

    /// Native code retains this context, never an unretained InputTap. A weak
    /// load cannot resurrect an owner whose deinit has already begun.
    private final class CallbackContext {
        weak var owner: InputTap?
        init(owner: InputTap) { self.owner = owner }
    }
    private final class NativeConnection {
        let tap: CFMachPort
        let source: CFRunLoopSource
        let context: UnsafeMutableRawPointer
        private var runLoop: CFRunLoop!
        private let exited = DispatchGroup()
        init(tap: CFMachPort, context: UnsafeMutableRawPointer) {
            self.tap = tap; self.context = context
            source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        }
        func start() {
            let ready = DispatchSemaphore(value: 0)
            exited.enter()
            let thread = Thread { [self] in
                runLoop = CFRunLoopGetCurrent()
                CFRunLoopAddSource(runLoop, source, .commonModes)
                ready.signal()
                CFRunLoopRun()
                CFRunLoopRemoveSource(runLoop, source, .commonModes)
                CFMachPortInvalidate(tap)
                Unmanaged<CallbackContext>.fromOpaque(context).release()
                exited.leave()
            }
            thread.name = "TinyHand event tap"
            thread.qualityOfService = .userInteractive
            thread.start()
            ready.wait()
        }
        func stop() {
            let invalidate = { [self] in
                CGEvent.tapEnable(tap: tap, enable: false)
                CFMachPortInvalidate(tap)
                CFRunLoopSourceInvalidate(source)
                CFRunLoopStop(runLoop)
            }
            if CFRunLoopGetCurrent() === runLoop {
                // The callback can release its final temporary owner on this
                // thread. Invalidate inline; thread cleanup releases the context
                // only after this callback has returned to the native run loop.
                invalidate()
            } else {
                CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue, invalidate)
                CFRunLoopWakeUp(runLoop)
                exited.wait()
            }
        }
    }

    func setActive(_ value: Bool) {
        lock.withLock {
            if active != value {
                active = value
                generation &+= 1
            }
            updateEnabled()
        }
    }

    private func updateEnabled() {
        guard tap != nil || connectionInstalled else { return }
        // Finish any press that started in Draw, even after turning the pointer off or changing mode.
        let desired = active || openingQuickControls || !presses.isEmpty || radial.needsTap || controls.needsTap
        if connectionEnabled != desired {
            if desired { radial.resetKeyboardObservation() }
            if let installation { installation.setEnabled(desired) }
            else if let tap { CGEvent.tapEnable(tap: tap, enable: desired) }
        }
    }

    func resetWait() {
        lock.withLock { _maxWaitMs = 0 }
    }

    private func notify(_ expected: UInt, _ body: @escaping (InputTap) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.lock.withLock({ self.active && self.generation == expected }) else {
                return
            }
            body(self)
        }
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        lock.withLock {
            eventCount += 1
            eventTypes[String(type.rawValue), default: 0] += 1
            radial.observeKeyboard(type, event: event)
            let forwarded = Unmanaged.passUnretained(event)
            if [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown].contains(type), sessionLocked() {
                // The login window owns locked-session input. Do not let drawing,
                // a stale popover or quick controls consume an unlock press.
                active = false
                generation &+= 1
                let key = type == .keyDown ? event.getIntegerValueField(.keyboardEventKeycode) : nil
                let button: Int64? = type == .keyDown ? nil : type == .leftMouseDown ? 0 : type == .rightMouseDown ? 1 : event.getIntegerValueField(.mouseEventButtonNumber)
                let ownedRepeat = key.map { event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                    && (controls.ownsKey($0) || radial.ownsPair(type, event: event)) } ?? false
                // This new system press owns its own release. Unrelated pairs
                // whose downs we captured still drain without leaking an up.
                if let button { presses.removeValue(forKey: button) }
                controls.suspendForSystem(releasingButton: button, key: ownedRepeat ? nil : key)
                radial.suspendForSystem(releasingButton: button, key: ownedRepeat ? nil : key)
                updateEnabled()
                DispatchQueue.main.async { [weak self] in self?.onScreenLocked?() }
                return ownedRepeat ? nil : forwarded
            }
            if event.timestamp > 0 {
                let wait = Double(DispatchTime.now().uptimeNanoseconds &- event.timestamp) / 1_000_000
                if wait < 600_000 {
                    _maxWaitMs = max(_maxWaitMs, wait)
                }
            }

            if type != .tapDisabledByTimeout && type != .tapDisabledByUserInput {
                // A newly opened surface cannot steal repeats or the release of
                // an existing owner, including a radial Escape held after cancel.
                if radial.ownsPair(type, event: event) {
                    _ = radial.handle(type, event: event, dragging: false)
                    updateEnabled(); return nil
                }
                let repeatedDrawButton: Int64?
                switch type {
                case .leftMouseDown: repeatedDrawButton = 0
                case .rightMouseDown: repeatedDrawButton = 1
                case .otherMouseDown: repeatedDrawButton = event.getIntegerValueField(.mouseEventButtonNumber)
                default: repeatedDrawButton = nil
                }
                if let button = repeatedDrawButton, presses[button] != nil { return nil }
                // Query only on a native-menu press, not on pointer movement.
                // Window Server bounds avoid a stale main-thread menu snapshot
                // during submenu opening. Only our own native menu rectangles
                // enter routing; no other application's metadata is retained.
                let menus: [CGRect]? = controls.needsMenuRegions(type) ? Self.nativeMenuRects() : nil
                let control = controls.handle(type, event: event, menuRegions: menus)
                if let secondary = control.statusClick { DispatchQueue.main.async { [weak self] in self?.onControlStatusClick?(secondary) } }
                if control.dismiss { DispatchQueue.main.async { [weak self] in self?.onDismissControls?() } }
                if control.consume { updateEnabled(); return nil }
                let dragging = type == .flagsChanged && (!presses.isEmpty || (0..<32).contains {
                    CGEventSource.buttonState(.combinedSessionState, button: CGMouseButton(rawValue: UInt32($0))!)
                })
                if radial.handle(type, event: event, dragging: dragging) { updateEnabled(); return nil }
            }
            switch type {
            case .tapDisabledByTimeout:
                updateEnabled()
                return forwarded
            case .tapDisabledByUserInput:
                // AppKit window tracking can disable taps. Retry from the UI service
                // tick instead of re-enabling recursively inside that notification.
                return forwarded
            case .leftMouseDown, .rightMouseDown, .otherMouseDown,
                 .leftMouseUp, .rightMouseUp, .otherMouseUp,
                 .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
                break
            default:
                return forwarded
            }

            let button: Int64
            switch type {
            case .leftMouseDown, .leftMouseUp, .leftMouseDragged: button = 0
            case .rightMouseDown, .rightMouseUp, .rightMouseDragged: button = 1
            default: button = event.getIntegerValueField(.mouseEventButtonNumber)
            }

            switch type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                presses.removeValue(forKey: button)
                guard active else {
                    if presses.isEmpty { updateEnabled() }
                    return forwarded
                }
                let location = event.location
                let flags = event.flags
                if _passThroughRects.contains(where: { $0.contains(location) }) {
                    notify(generation) { $0.onPassThroughPress?(location) }
                    return forwarded
                }
                presses[button] = Press(generation: generation)
                notify(generation) { $0.onMouseDown?(button, .draw, location, flags) }
                return nil

            case .leftMouseUp, .rightMouseUp, .otherMouseUp:
                guard let press = presses.removeValue(forKey: button) else { return forwarded }
                if !active && presses.isEmpty { updateEnabled() }
                notify(press.generation) { $0.onMouseUp?(button, .draw) }
                return nil

            default:
                guard let press = presses[button] else { return forwarded }
                if type == .leftMouseDragged {
                    let point = event.location
                    notify(press.generation) { $0.onLeftDragged?(point) }
                }
                event.type = .mouseMoved
                return forwarded
            }
        }
    }

    private static func nativeMenuRects() -> [CGRect]? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        return windows.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? Int32) == ProcessInfo.processInfo.processIdentifier,
                  (info[kCGWindowLayer as String] as? Int) == Int(CGWindowLevelForKey(.popUpMenuWindow)),
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: bounds as CFDictionary)
        }
    }
}
