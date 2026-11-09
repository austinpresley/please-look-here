import AppKit

final class InputTap {
    enum Feedback {
        case draw, interact
    }

    var onMouseDown: ((Int64, Feedback, CGPoint, CGEventFlags) -> Void)?
    var onMouseUp: ((Int64, Feedback) -> Void)?
    var onLeftDragged: ((CGPoint) -> Void)?
    var onPassThroughPress: ((CGPoint) -> Void)?
    var hardwareFlags: () -> CGEventFlags = { CGEventSource.flagsState(.hidSystemState) }

    private enum Route {
        case draw
        case interact(CGEventFlags)
    }

    private struct Press {
        let route: Route
        let generation: UInt
    }

    private let lock = NSLock()
    private var active = false
    private var generation: UInt = 0
    private var presses: [Int64: Press] = [:]
    private var _passThroughRects: [CGRect] = []
    private var _interactKey: CGEventFlags = []
    private var _maxWaitMs: Double = 0
    private var eventCount = 0
    private var eventTypes: [String: Int] = [:]
    var diagnostics: [String: Any] {
        lock.withLock { ["installed": tap != nil, "enabled": tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false, "active": active, "events": eventCount, "types": eventTypes] }
    }

    var passThroughRects: [CGRect] {
        get { lock.withLock { _passThroughRects } }
        set { lock.withLock { _passThroughRects = newValue } }
    }

    var interactKey: CGEventFlags {
        get { lock.withLock { _interactKey } }
        set { lock.withLock { _interactKey = newValue } }
    }

    var interactPressing: Bool {
        lock.withLock {
            active && presses.values.contains {
                if case .interact = $0.route { return $0.generation == generation }
                return false
            }
        }
    }

    var maxWaitMs: Double { lock.withLock { _maxWaitMs } }
    private var tap: CFMachPort?
    private var eventRunLoop: CFRunLoop?
    var isInstalled: Bool { lock.withLock { tap != nil } }

    @discardableResult
    func install() -> Bool {
        guard !isInstalled else {
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
            (1 << CGEventType.otherMouseDragged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let me = Unmanaged<InputTap>.fromOpaque(refcon).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }
        CGEvent.tapEnable(tap: tap, enable: false)

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            let runLoop = CFRunLoopGetCurrent()
            self?.lock.withLock { self?.eventRunLoop = runLoop }
            CFRunLoopAddSource(runLoop, source, .commonModes)
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = "TinyHand event tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()

        lock.withLock {
            self.tap = tap
            updateEnabled()
        }
        return true
    }

    deinit {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let runLoop = eventRunLoop { CFRunLoopStop(runLoop) }
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
        guard let tap = tap else { return }
        // Finish any press that started in Draw, even after Esc or a mode change.
        let desired = active || !presses.isEmpty
        if CGEvent.tapIsEnabled(tap: tap) != desired { CGEvent.tapEnable(tap: tap, enable: desired) }
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
            let forwarded = Unmanaged.passUnretained(event)
            if event.timestamp > 0 {
                let wait = Double(DispatchTime.now().uptimeNanoseconds &- event.timestamp) / 1_000_000
                if wait < 600_000 {
                    _maxWaitMs = max(_maxWaitMs, wait)
                }
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
                let key = _interactKey
                if !key.isEmpty && (event.flags.contains(key) || hardwareFlags().contains(key)) {
                    presses[button] = Press(route: .interact(key), generation: generation)
                    event.flags.remove(key)
                    notify(generation) { $0.onMouseDown?(button, .interact, location, flags) }
                    return forwarded
                }
                presses[button] = Press(route: .draw, generation: generation)
                notify(generation) { $0.onMouseDown?(button, .draw, location, flags) }
                return nil

            case .leftMouseUp, .rightMouseUp, .otherMouseUp:
                guard let press = presses.removeValue(forKey: button) else { return forwarded }
                if !active && presses.isEmpty { updateEnabled() }
                switch press.route {
                case .draw:
                    notify(press.generation) { $0.onMouseUp?(button, .draw) }
                    return nil
                case .interact(let key):
                    event.flags.remove(key)
                    notify(press.generation) { $0.onMouseUp?(button, .interact) }
                    return forwarded
                }

            default:
                guard let press = presses[button] else { return forwarded }
                switch press.route {
                case .draw:
                    if type == .leftMouseDragged {
                        let point = event.location
                        notify(press.generation) { $0.onLeftDragged?(point) }
                    }
                    event.type = .mouseMoved
                case .interact(let key):
                    event.flags.remove(key)
                }
                return forwarded
            }
        }
    }
}
