import AppKit

final class ArmView: NSView {
    private let group = CALayer()
    private let contactShadow = ContactShadowLayer()
    private let rodLayer = CALayer()
    private let handLayer = CALayer()
    private let dotLayer = CAShapeLayer()
    private let dotCore = CAShapeLayer()
    private let gestureMarker = CAShapeLayer()
    private let spotlight = SpotlightLayer()
    private let presentation = PresentationPointerLayer()

    private(set) var style: PointerStyle = .lavender
    private var asset: HandAsset?
    private var baseAsset: HandAsset?
    private(set) var activeGesture: HandGestureSlot?

    private var previewConfiguration: PointerPreviewConfiguration?
    private var handLenFrac: CGFloat = Preferences.pointerSize
    private var showShadow = Preferences.showShadow
    private var shadowStyle = Preferences.shadowStyle
    private var lastCursor: CGPoint?
    private let minRodFrac: CGFloat = 0.05
    private let gripLeanFrac: CGFloat = 0.30
    private let gripDepthFrac: CGFloat = 0.12
    private let liftFrac: CGFloat = 0.06

    let annotations = DisplayInkStore()
    var ink: Ink { annotations.ink }
    var held = false { didSet { if oldValue && !held { swing.release(at: CACurrentMediaTime()) } } }
    var inkWidth: CGFloat { Preferences.strokeWidth }

    private var pressAmount: CGFloat = 0
    private var swing = TapSwing()
    var tapSoundDelay: TimeInterval { swing.contactDelay }
    private var shadowResponse = ContactShadowResponse()
    private var gripX: CGFloat?
    private var lastPose: [CGFloat] = []
    private var lastLaserPose: [CGFloat] = []
    private var gripTarget: CGFloat?
    private var displayImageHeight = 0

    var isSettling: Bool {
        if pressAmount > 0.002 || shadowResponse.amount > 0 || swing.active {
            return true
        }
        guard let gx = gripX, let target = gripTarget else {
            return false
        }
        return abs(target - gx) > 0.5
    }

    var pointerHidden = false {
        didSet {
            lastPose = []
            if pointerHidden { contactShadow.disable() }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            group.isHidden = pointerHidden || style.assetName == nil
            dotLayer.isHidden = pointerHidden || style != .laser
            spotlight.layer.isHidden = pointerHidden || style != .spotlight
            presentation.layer.isHidden = pointerHidden || style != .presentation
            gestureMarker.isHidden = pointerHidden || activeGesture == nil
            CATransaction.commit()
        }
    }

    override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, previewConfiguration: nil)
    }

    /// A preview receives explicit values and never subscribes to live preference changes.
    init(frame frameRect: NSRect, previewConfiguration: PointerPreviewConfiguration?) {
        self.previewConfiguration = previewConfiguration
        super.init(frame: frameRect)
        let root = CALayer()
        root.masksToBounds = false
        layer = root
        wantsLayer = true
        root.addSublayer(annotations.layer)
        root.addSublayer(spotlight.layer)
        root.addSublayer(group)
        root.addSublayer(presentation.layer)

        root.addSublayer(dotLayer)
        root.addSublayer(gestureMarker)
        gestureMarker.path = CGPath(ellipseIn: CGRect(x: -4, y: -4, width: 8, height: 8), transform: nil)
        gestureMarker.fillColor = NSColor.black.cgColor; gestureMarker.strokeColor = NSColor.white.cgColor
        gestureMarker.lineWidth = 2; gestureMarker.isHidden = true

        group.masksToBounds = false
        group.addSublayer(contactShadow.layer)
        group.addSublayer(rodLayer)
        group.addSublayer(handLayer)
        for sub in [rodLayer, handLayer] {
            sub.contentsGravity = .resize
            sub.contentsScale = 2
            sub.anchorPoint = CGPoint(x: 0.5, y: 0)
            sub.shadowColor = NSColor.black.cgColor
            sub.shadowOpacity = 0.38
        }

        dotLayer.fillColor = Ink.red
        dotLayer.shadowColor = Ink.red
        dotLayer.shadowOpacity = 1
        dotLayer.shadowOffset = .zero
        dotCore.fillColor = CGColor(srgbRed: 1, green: 0.86, blue: 0.82, alpha: 0.95)
        dotLayer.addSublayer(dotCore)

        setStyle(previewConfiguration?.style ?? PointerStyle.saved)
        if let previewConfiguration { applyPreviewConfiguration(previewConfiguration) }
        contactShadow.didUpdate = { [weak self] in
            guard let self, let cursor = self.lastCursor else { return }
            self.lastPose = []
            self.aim(cursor: cursor)
        }
        if previewConfiguration == nil {
            NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [weak self] _ in
                self?.updatePointerConfiguration()
            }
        }
    }

    private func updatePointerConfiguration() {
        if let configuration = previewConfiguration {
            handLenFrac = configuration.size
            showShadow = configuration.shadow
            shadowStyle = configuration.shadowStyle
        } else {
            let configuration = Preferences.pointerConfiguration(for: style.rawValue)
            handLenFrac = CGFloat(configuration.size)
            showShadow = configuration.shadow
            shadowStyle = configuration.shadowStyle
        }
        lastPose = []; lastLaserPose = []
    }

    func applyPreviewConfiguration(_ configuration: PointerPreviewConfiguration) {
        guard previewConfiguration != nil else { return }
        previewConfiguration = configuration
        if style != configuration.style { setStyle(configuration.style) }
        updatePointerConfiguration()
        displayImageHeight = 0
    }

    func updateInkColor() {
        ink.color = Preferences.inkChoice.resolved(for: style)
        ink.tool = Preferences.drawingTool
        ink.opacity = Preferences.inkOpacity
        ink.smoothing = Preferences.strokeSmoothing
    }
    func installMagnifier(_ lens: CALayer) { layer?.insertSublayer(lens, below: group) }

    func setStyle(_ newStyle: PointerStyle) {
        cancelTapAnimation()
        contactShadow.reset()
        lastPose = []
        style = newStyle
        asset = newStyle.assetName.flatMap(HandAsset.load)
        baseAsset = asset; activeGesture = nil
        if newStyle.assetName != nil && asset == nil {
            style = .laser
        }
        updatePointerConfiguration()
        updateInkColor()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let a = asset, style != .laser {
            group.anchorPoint = CGPoint(x: a.rodX, y: 0)
            displayImageHeight = 0
            updateDisplayImage(a)
            rodLayer.contentsRect = CGRect(x: 0, y: 1 - a.rodEnd, width: 1, height: a.rodEnd - a.wrist)
            handLayer.contentsRect = CGRect(x: 0, y: 1 - a.wrist, width: 1, height: a.wrist - a.handTop)
        }
        CATransaction.commit()
        let hidden = pointerHidden
        pointerHidden = hidden
    }
    @discardableResult func setGesture(_ slot: HandGestureSlot?) -> Bool {
        guard activeGesture != slot else { return true }
        if let slot {
            guard let baseAsset, let image = HandGestureCatalog.image(slot, style: style) else { return false }
            asset = baseAsset.replacingImage(image)
        } else { asset = baseAsset }
        activeGesture = slot
        displayImageHeight = 0; lastPose = []; contactShadow.reset()
        if let asset { updateDisplayImage(asset) }
        gestureMarker.isHidden = pointerHidden || slot == nil
        return true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not used")
    }

    func press() {
        pressAmount = 1
        swing.begin(at: CACurrentMediaTime(), range: CGFloat(previewConfiguration?.tapSwing ?? Preferences.tapSwing),
                    reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || style.assetName == nil)
        shadowResponse.press(at: CACurrentMediaTime())
    }
    func reachTapContact() { swing.reachContact(at: CACurrentMediaTime()) }
    func cancelTapAnimation() { swing.cancel(); pressAmount = 0; lastPose = [] }

    // A compact sample uses a fixed reference height so hands and contact shadows
    // stay readable at the same settings as the full desktop renderer.
    private var renderingHeight: CGFloat { previewConfiguration == nil ? bounds.height : max(720, bounds.height) }

    func aim(cursor: CGPoint) {
        lastCursor = cursor
        gestureMarker.position = cursor
        let screenH = renderingHeight
        let targetX = min(max(cursor.x + gripLeanFrac * bounds.width, bounds.width * 0.15), bounds.width * 1.05)
        let gx = (previewConfiguration?.motion ?? Preferences.pointerMotion).gripPosition(previous: gripX, target: targetX)
        gripX = gx
        gripTarget = targetX
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { swing.cancel() }
        let swings = swing.active
        let tap = swing.pose(at: CACurrentMediaTime(), held: held)
        let grip = CGPoint(x: gx + tap.gripX * screenH, y: (tap.gripY - gripDepthFrac) * screenH)

        if !held {
            pressAmount += (0 - pressAmount) * 0.18
        }
        shadowResponse.update(at: CACurrentMediaTime(), held: held)
        let press = swings ? tap.press : pressAmount

        if style == .laser {
            contactShadow.disable()
            aimLaser(cursor: cursor)
            return
        }
        if style == .spotlight || style == .presentation {
            contactShadow.disable()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let scale = window?.backingScaleFactor ?? 2
            if style == .spotlight {
                spotlight.update(cursor: cursor, bounds: bounds, size: handLenFrac, scale: scale)
            } else {
                let pose = PresentationPointerPose(cursor: cursor, grip: grip, height: screenH, size: handLenFrac)
                presentation.update(pose, press: pressAmount, shadow: showShadow, scale: scale)
            }
            CATransaction.commit()
            return
        }
        guard let a = asset else {
            return
        }
        updateDisplayImage(a)

        let toCursor = CGPoint(x: cursor.x - grip.x, y: cursor.y - grip.y)
        let distance = max(1, hypot(toCursor.x, toCursor.y))
        let dx = toCursor.x - toCursor.x / distance * tap.poke * screenH + tap.tipX * screenH
        let dy = toCursor.y - toCursor.y / distance * tap.poke * screenH + tap.tipY * screenH
        let reach = hypot(dx, dy)
        let aimAngle = atan2(dy, dx)

        let handPts = handLenFrac * screenH * (1 - (swings ? 0.10 : 0.06) * press)
        let s = handPts / (a.wrist - a.handTop)
        let widthPts = s * a.aspect
        let handTipPts = (a.wrist - a.tip) * s
        let tipOffX = (a.tipX - a.rodX) * widthPts

        let along = sqrt(max(0, reach * reach - tipOffX * tipOffX))
        var rodLen = along - handTipPts
        rodLen = max(minRodFrac * screenH, rodLen)
        let tipAngle = atan2(rodLen + handTipPts, tipOffX)
        let rotation = aimAngle - tipAngle + tap.tilt

        let lift = liftFrac * screenH * (1 - 0.8 * press)
        let sx = lift * 0.6
        let sy = -lift
        let shadowOffset = CGSize(
            width: sx * cos(-rotation) - sy * sin(-rotation),
            height: sx * sin(-rotation) + sy * cos(-rotation)
        )

        let contact = swings ? max(0, press) : shadowResponse.amount
        let pose = [rotation, rodLen, handPts, widthPts, grip.x, grip.y, lift, press,
                    shadowResponse.amount, showShadow ? 1 : 0, a.aspect]
            .map { ($0 * 100).rounded() }
        guard pose != lastPose else {
            return
        }
        lastPose = pose

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if showShadow && shadowStyle == .contact && !pointerHidden && activeGesture == nil {
            contactShadow.update(ContactShadowPose(asset: a, width: widthPts, height: handPts,
                                                  rodLength: rodLen, rotation: rotation, press: contact))
        } else {
            contactShadow.disable()
        }
        let originalShadow = showShadow && (activeGesture != nil || shadowStyle == .original || !contactShadow.isReady)
        for sub in [rodLayer, handLayer] {
            sub.shadowOffset = shadowOffset
            sub.shadowRadius = max(1, lift * 0.35) + 5 * max(0, press)
            sub.shadowOpacity = originalShadow ? Float(0.26 + 0.02 * max(0, press)) : 0
        }

        rodLayer.bounds = CGRect(x: 0, y: 0, width: widthPts, height: rodLen)
        rodLayer.position = CGPoint(x: widthPts / 2, y: 0)
        handLayer.bounds = CGRect(x: 0, y: 0, width: widthPts, height: handPts)
        handLayer.position = CGPoint(x: widthPts / 2, y: rodLen)

        group.bounds = CGRect(x: 0, y: 0, width: widthPts, height: rodLen + handPts)
        group.position = grip
        group.transform = CATransform3DMakeRotation(rotation, 0, 0, 1)

        CATransaction.commit()
    }

    var shadowDiagnostics: [String: Any] { contactShadow.diagnostics }

    private func aimLaser(cursor: CGPoint) {
        let press = pressAmount
        let r = max(previewConfiguration == nil ? 4 : 1, renderingHeight * 0.0038 * handLenFrac / 0.13) * (1 + 0.2 * press)
        let laserPose = [r, cursor.x, cursor.y].map { ($0 * 100).rounded() }
        guard laserPose != lastLaserPose else {
            return
        }
        lastLaserPose = laserPose
        let core = r * 0.45
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let dot = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        dotLayer.path = dot
        dotLayer.shadowPath = dot
        dotCore.path = CGPath(ellipseIn: CGRect(x: -core, y: -core, width: 2 * core, height: 2 * core), transform: nil)
        dotLayer.position = cursor
        dotLayer.shadowRadius = r * (2.2 + 1.0 * press)
        CATransaction.commit()
    }

    private func updateDisplayImage(_ a: HandAsset) {
        let full = a.image
        let scale = window?.backingScaleFactor ?? 2
        let restPts = handLenFrac * renderingHeight / (a.wrist - a.handTop)
        let step = 64
        let needed = (Int((restPts * scale).rounded(.up)) + step - 1) / step * step
        let height = needed >= full.height * 9 / 10 ? full.height : max(step, needed)
        guard height != displayImageHeight else {
            return
        }
        displayImageHeight = height
        let image = height == full.height ? full : HandAsset.resized(full, height: height) ?? full
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rodLayer.contents = image
        handLayer.contents = image
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        applyBackingScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        applyBackingScale()
    }

    private func applyBackingScale() {
        let scale = window?.backingScaleFactor ?? 2
        rodLayer.contentsScale = scale
        handLayer.contentsScale = scale
        ink.scale = scale
    }
}
