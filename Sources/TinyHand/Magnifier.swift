import AppKit
import CoreVideo
import IOSurface

struct MagnifierTarget: Equatable {
    let id: CGDirectDisplayID
    let frame: CGRect
    let scale: CGFloat
    init(id: CGDirectDisplayID, frame: CGRect, scale: CGFloat) { self.id = id; self.frame = frame; self.scale = scale }
    init?(_ screen: NSScreen) {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }
        self.init(id: id, frame: screen.frame, scale: screen.backingScaleFactor)
    }
}

struct MagnifierLayout {
    let lens: CGRect
    let sample: CGRect
    let cursor: CGPoint
    init?(mouse: CGPoint, display: CGRect, diameter: CGFloat, zoom: CGFloat) {
        guard display.width > 0, display.height > 0, diameter.isFinite, zoom.isFinite, zoom > 1 else { return nil }
        let size = min(max(96, diameter), min(display.width, display.height))
        let p = CGPoint(x: min(max(0, mouse.x - display.minX), display.width),
                        y: min(max(0, mouse.y - display.minY), display.height))
        let center = CGPoint(x: min(max(size / 2, p.x), display.width - size / 2),
                             y: min(max(size / 2, p.y), display.height - size / 2))
        lens = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        let w = size / zoom / display.width, h = size / zoom / display.height
        let u = min(max(0, p.x / display.width - w / 2), 1 - w)
        let v = min(max(0, p.y / display.height - h / 2), 1 - h)
        sample = CGRect(x: u, y: v, width: w, height: h)
        cursor = CGPoint(x: (p.x / display.width - u) / w * size, y: (p.y / display.height - v) / h * size)
    }
}

struct MagnifierFrame {
    let buffer: CVPixelBuffer
    /// The captured display's valid image rectangle, in bottom-left unit coordinates.
    let content: CGRect
}

protocol MagnifierCaptureDriver: AnyObject {
    func start(frame: @escaping (MagnifierFrame) -> Void, failure: @escaping (Error) -> Void)
    func stop(completion: @escaping () -> Void)
}

/// UI-owned capture lifecycle and lens. Drivers publish only coalesced main-queue frames.
final class MagnifierController {
    let layer = CALayer()
    private let image = CALayer()
    private let mark = CAShapeLayer()
    private let factory: (MagnifierTarget) -> MagnifierCaptureDriver
    private let startupDeadline: TimeInterval
    private var desired: MagnifierTarget?
    private var current: MagnifierTarget?
    private var driver: MagnifierCaptureDriver?
    private var retiring: MagnifierCaptureDriver?
    private var token: UUID?
    private var stopping = false
    private var startupTimeout: DispatchWorkItem?
    private var displayed: MagnifierFrame?
    private var layout: MagnifierLayout?
    private(set) var state = "off"
    private(set) var frameCount = 0
    private(set) var lastError: String?
    var onFailure: ((String) -> Void)?
    var visible: Bool { !layer.isHidden && displayed != nil }

    init(startupDeadline: TimeInterval = 4,
         factory: @escaping (MagnifierTarget) -> MagnifierCaptureDriver = { ScreenMagnifierCapture(target: $0) }) {
        self.factory = factory
        self.startupDeadline = startupDeadline
        layer.isHidden = true
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.3; layer.shadowRadius = 12; layer.shadowOffset = CGSize(width: 0, height: -4)
        image.masksToBounds = true; image.contentsGravity = .resize
        image.borderWidth = 2; image.borderColor = NSColor.white.withAlphaComponent(0.95).cgColor
        mark.fillColor = nil; mark.strokeColor = NSColor.black.cgColor; mark.lineWidth = 2
        mark.shadowColor = NSColor.white.cgColor; mark.shadowOpacity = 1; mark.shadowRadius = 1; mark.shadowOffset = .zero
        layer.addSublayer(image); image.addSublayer(mark)
    }

    func update(target: MagnifierTarget, mouse: CGPoint, zoom: CGFloat, diameter: CGFloat) {
        guard let layout = MagnifierLayout(mouse: mouse, display: target.frame, diameter: diameter, zoom: zoom) else { suspend(); return }
        self.layout = layout
        if desired != target {
            desired = target
            if current != target { displayed = nil; image.contents = nil; layer.isHidden = true }
            transition()
        }
        applyLayout()
    }
    func suspend(keepingImage: Bool = false) {
        if desired == nil && driver == nil && (keepingImage || displayed == nil) { return }
        desired = nil
        startupTimeout?.cancel(); startupTimeout = nil
        if !keepingImage { displayed = nil; image.contents = nil; layer.isHidden = true }
        transition()
    }
    private func transition() {
        guard !stopping else { return }
        if driver != nil && current == desired { return }
        if let old = driver {
            token = nil; driver = nil; current = nil
            retiring = old
            stopping = true; state = "stopping"
            old.stop { [weak self] in
                guard let self else { return }
                self.stopping = false
                self.retiring = nil
                self.state = "off"
                self.transition()
            }
            return
        }
        guard let desired else { state = "off"; return }
        let identity = UUID(), next = factory(desired)
        token = identity; driver = next; current = desired
        state = "starting"; lastError = nil
        startupTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.token == identity, self.displayed == nil else { return }
            self.fail("The screen did not produce a magnifier frame. Check Screen Recording access and try again.")
        }
        startupTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + startupDeadline, execute: timeout)
        next.start(frame: { [weak self] frame in
            guard let self, self.token == identity, self.desired == self.current else { return }
            self.startupTimeout?.cancel(); self.startupTimeout = nil
            self.displayed = frame; self.frameCount += 1; self.state = "running"
            self.applyLayout()
        }, failure: { [weak self] error in
            guard let self, self.token == identity else { return }
            Log.write("Magnification capture failed: \(error.localizedDescription)")
            self.fail("Magnification stopped. Check Screen Recording access and try again.")
        })
    }
    private func fail(_ message: String) {
        lastError = message
        suspend()
        onFailure?(message)
    }
    private func applyLayout() {
        guard let layout, let displayed,
              let surface = CVPixelBufferGetIOSurface(displayed.buffer)?.takeUnretainedValue() else { return }
        let valid = displayed.content
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.frame = layout.lens
        layer.shadowPath = CGPath(ellipseIn: layer.bounds, transform: nil)
        image.frame = layer.bounds; image.cornerRadius = layer.bounds.width / 2
        image.contents = surface
        image.contentsRect = CGRect(x: valid.minX + layout.sample.minX * valid.width,
                                    y: valid.minY + layout.sample.minY * valid.height,
                                    width: layout.sample.width * valid.width, height: layout.sample.height * valid.height)
        mark.path = CGPath(ellipseIn: CGRect(x: -4, y: -4, width: 8, height: 8), transform: nil)
        mark.position = layout.cursor
        layer.isHidden = false
        CATransaction.commit()
    }
    var diagnostics: [String: Any] {
        ["state": state, "visible": visible, "frames": frameCount, "display": current?.id ?? 0,
         "error": lastError ?? "", "fpsLimit": 30, "queueDepth": 3,
         "frame": [layer.frame.minX, layer.frame.minY, layer.frame.width, layer.frame.height],
         "sample": layout.map { [$0.sample.minX, $0.sample.minY, $0.sample.width, $0.sample.height] } ?? []]
    }
    deinit {
        startupTimeout?.cancel()
        driver?.stop(completion: {})
        retiring?.stop(completion: {})
    }
}
