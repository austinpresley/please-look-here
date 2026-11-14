import AppKit

/// The aperture is transparent, so live content and native input need no capture permission.
final class SpotlightLayer {
    let layer = CALayer()
    private let shade = CALayer()
    private let mask = CALayer()
    private let outside = (0..<4).map { _ in CALayer() }
    private let feather = CALayer()
    private let center = CAShapeLayer()
    private var lastPose: [CGFloat] = []
    static let dimming: CGFloat = 0.62
    private static let clearFraction: CGFloat = 0.85

    init() {
        shade.backgroundColor = NSColor.black.withAlphaComponent(Self.dimming).cgColor
        shade.mask = mask
        for rectangle in outside {
            rectangle.backgroundColor = NSColor.white.cgColor
            mask.addSublayer(rectangle)
        }
        feather.contents = Self.featherImage()
        mask.addSublayer(feather)
        center.path = CGPath(ellipseIn: CGRect(x: -2, y: -2, width: 4, height: 4), transform: nil)
        center.fillColor = NSColor.white.cgColor
        center.strokeColor = NSColor.black.withAlphaComponent(0.8).cgColor
        center.lineWidth = 1
        layer.addSublayer(shade)
        layer.addSublayer(center)
    }

    static func radius(height: CGFloat, size: CGFloat) -> CGFloat {
        min(360, max(60, height * size))
    }

    func update(cursor: CGPoint, bounds: CGRect, size: CGFloat, scale: CGFloat) {
        let radius = Self.radius(height: bounds.height, size: size)
        let outer = radius / Self.clearFraction
        let pose = [cursor.x, cursor.y, bounds.width, bounds.height, bounds.minX, bounds.minY, radius, scale]
        guard pose != lastPose else { return }
        lastPose = pose
        shade.frame = bounds
        mask.frame = CGRect(origin: .zero, size: bounds.size)
        let aperture = CGRect(x: cursor.x - bounds.minX - outer, y: cursor.y - bounds.minY - outer, width: outer * 2, height: outer * 2)
        feather.frame = aperture
        // Overlap opaque mask edges. Dimming is applied once, after the mask is composited,
        // so these joins cannot create a bright seam or a second layer of darkness.
        let left = min(bounds.width, max(0, aperture.minX + 2))
        let right = min(bounds.width, max(0, aperture.maxX - 2))
        let bottom = min(bounds.height, max(0, aperture.minY + 2))
        let top = min(bounds.height, max(0, aperture.maxY - 2))
        outside[0].frame = CGRect(x: 0, y: 0, width: left, height: bounds.height)
        outside[1].frame = CGRect(x: right, y: 0, width: bounds.width - right, height: bounds.height)
        outside[2].frame = CGRect(x: 0, y: 0, width: bounds.width, height: bottom)
        outside[3].frame = CGRect(x: 0, y: top, width: bounds.width, height: bounds.height - top)
        center.position = cursor
        center.contentsScale = scale
    }

    private static func featherImage() -> CGImage? {
        let side = 512
        let radius = CGFloat(side) / 2
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [NSColor.clear.cgColor, NSColor.white.cgColor] as CFArray,
                                        locations: [0, 1]) else { return nil }
        let center = CGPoint(x: radius, y: radius)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: radius * clearFraction,
                                   endCenter: center, endRadius: radius, options: [.drawsAfterEndLocation])
        return context.makeImage()
    }
}

struct PresentationPointerPose {
    let grip: CGPoint
    let length: CGFloat
    let rotation: CGFloat
    let width: CGFloat

    init(cursor: CGPoint, grip: CGPoint, height: CGFloat, size: CGFloat) {
        self.grip = grip
        length = hypot(cursor.x - grip.x, cursor.y - grip.y)
        rotation = atan2(cursor.y - grip.y, cursor.x - grip.x) - .pi / 2
        width = min(22, max(5, height * size * 0.075))
    }

    var tip: CGPoint {
        CGPoint(x: grip.x - sin(rotation) * length, y: grip.y + cos(rotation) * length)
    }
}

/// Three nested metal sections stay attached to a fixed-size grip and rubber tip.
final class PresentationPointerLayer {
    let layer = CALayer()
    private let shafts = (0..<3).map { _ in CAGradientLayer() }
    private let collars = (0..<2).map { _ in CAGradientLayer() }
    private let grip = CAGradientLayer()
    private let tip = CAGradientLayer()
    private let ribs = CAShapeLayer()
    private var lastPose: [CGFloat] = []

    init() {
        layer.anchorPoint = .zero
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOffset = CGSize(width: 5, height: -6)
        layer.shadowRadius = 5
        let metal: [UInt32] = [0x66717E, 0xE2E7EC, 0xFFFFFF, 0xB2BBC5, 0x717B87]
        for shaft in shafts {
            configure(shaft, colors: metal)
            layer.addSublayer(shaft)
        }
        for collar in collars {
            configure(collar, colors: [0x414952, 0xD6DEE6, 0x707C89])
            layer.addSublayer(collar)
        }
        configure(grip, colors: [0x151821, 0x454B58, 0x222631, 0x0D1017])
        configure(tip, colors: [0xA92E36, 0xFF9182, 0xEE6B61, 0xBE4143])
        ribs.strokeColor = NSColor.black.withAlphaComponent(0.35).cgColor
        ribs.lineWidth = 1
        layer.addSublayer(grip)
        layer.addSublayer(ribs)
        layer.addSublayer(tip)
    }

    private func configure(_ value: CAGradientLayer, colors: [UInt32]) {
        value.colors = colors.map(Ink.hex)
        value.startPoint = CGPoint(x: 0, y: 0.5)
        value.endPoint = CGPoint(x: 1, y: 0.5)
    }

    func update(_ pose: PresentationPointerPose, press: CGFloat, shadow: Bool, scale: CGFloat) {
        let values = [pose.grip.x, pose.grip.y, pose.length, pose.rotation, pose.width, press, shadow ? 1 : 0, scale]
        guard values != lastPose else { return }
        lastPose = values
        let width = pose.width
        let tipHeight = min(pose.length * 0.1, max(12, width * 1.8))
        let shaftLength = max(0, pose.length - tipHeight * 0.65)
        for (index, shaft) in shafts.enumerated() {
            let segmentWidth = width * (1 - CGFloat(index) * 0.19)
            shaft.frame = CGRect(x: -segmentWidth / 2, y: CGFloat(index) * shaftLength / 3,
                                 width: segmentWidth, height: shaftLength / 3 + 1)
            shaft.cornerRadius = segmentWidth / 2
            shaft.contentsScale = scale
        }
        for (index, collar) in collars.enumerated() {
            let collarWidth = width * (1.08 - CGFloat(index) * 0.19)
            collar.frame = CGRect(x: -collarWidth / 2, y: CGFloat(index + 1) * shaftLength / 3 - 2,
                                  width: collarWidth, height: 4)
            collar.cornerRadius = 1
        }
        let gripHeight = min(pose.length * 0.28, max(64, width * 8))
        let gripWidth = width * 1.75
        grip.frame = CGRect(x: -gripWidth / 2, y: 0, width: gripWidth, height: gripHeight)
        grip.cornerRadius = gripWidth / 2
        let lines = CGMutablePath()
        for y in stride(from: CGFloat(12), to: gripHeight - 8, by: 5) {
            lines.move(to: CGPoint(x: -gripWidth * 0.38, y: y))
            lines.addLine(to: CGPoint(x: gripWidth * 0.38, y: y))
        }
        ribs.path = lines
        ribs.contentsScale = scale
        let tipWidth = max(6, width * 0.95) * (1 + press * 0.06)
        tip.frame = CGRect(x: -tipWidth / 2, y: pose.length - tipHeight, width: tipWidth, height: tipHeight)
        tip.cornerRadius = tipWidth / 2
        layer.position = pose.grip
        layer.transform = CATransform3DMakeRotation(pose.rotation, 0, 0, 1)
        layer.shadowOpacity = shadow ? 0.25 : 0
        layer.shadowPath = CGPath(roundedRect: CGRect(x: -gripWidth / 2, y: 0, width: gripWidth, height: pose.length),
                                 cornerWidth: width / 2, cornerHeight: width / 2, transform: nil)
    }
}

enum PresentationPointerArtwork {
    private static var icons: [PointerStyle: NSImage] = [:]

    static func icon(for style: PointerStyle) -> NSImage? {
        guard style == .spotlight || style == .presentation else { return nil }
        if let cached = icons[style] { return cached }
        let side = 128
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if style == .spotlight {
            let path = CGPath(roundedRect: CGRect(x: 6, y: 6, width: 116, height: 116), cornerWidth: 24, cornerHeight: 24, transform: nil)
            context.addPath(path)
            context.clip()
            context.setFillColor(Ink.hex(0xEECD79))
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            // Use the same aperture renderer as the live pointer at icon scale.
            let spotlight = SpotlightLayer()
            spotlight.update(cursor: CGPoint(x: 128, y: 128), bounds: CGRect(x: 0, y: 0, width: 256, height: 256), size: 0.13, scale: 2)
            context.scaleBy(x: 0.5, y: 0.5)
            spotlight.layer.render(in: context)
        } else {
            let pointer = PresentationPointerLayer()
            pointer.update(PresentationPointerPose(cursor: CGPoint(x: 28, y: 112), grip: CGPoint(x: 104, y: 12), height: 128, size: 0.7),
                           press: 0, shadow: true, scale: 2)
            // render(in:) ignores the root layer's position and transform. Keep the rod as a child.
            let canvas = CALayer()
            canvas.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            canvas.addSublayer(pointer.layer)
            canvas.render(in: context)
        }
        CATransaction.commit()
        guard let image = context.makeImage() else { return nil }
        let icon = NSImage(cgImage: image, size: CGSize(width: side, height: side))
        icons[style] = icon
        return icon
    }
}
