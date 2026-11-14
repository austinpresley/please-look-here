import AppKit

/// Draws a key: white symbols on black, lavender border and check for observed state.
enum KeyArt {
    static let side = 144
    private static let accent = NSColor(red: 0.67, green: 0.56, blue: 1, alpha: 1)
    private static let amber = NSColor(red: 1, green: 0.74, blue: 0.2, alpha: 1)
    private static let red = NSColor(red: 1, green: 0.32, blue: 0.3, alpha: 1)
    private static let green = NSColor(red: 0.3, green: 0.85, blue: 0.5, alpha: 1)

    static func png(_ face: KeyFace, image: CGImage?) -> Data? {
        render(side: side, draw: { draw(face, image: image) })
    }

    static func render(side: Int, draw: () -> Void) -> Data? {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func draw(_ face: KeyFace, image: CGImage?) {
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        NSColor.black.setFill()
        bounds.fill()
        let content = face.detail == nil ? CGRect(x: 18, y: 42, width: 108, height: 90) : CGRect(x: 18, y: 60, width: 108, height: 72)
        let color = glyphColor(face)
        switch face.glyph {
        case .style:
            if let image { drawThumbnail(image, in: content, dimmed: face.tone == .idle) } else { symbol("questionmark.square.dashed", in: content, color: amber) }
        case .laser: drawLaser(in: content, dimmed: face.tone == .idle)
        default: symbol(symbolName(face.glyph), in: content, color: color)
        }
        drawLabel(face)
        if face.tone == .active { border(accent, inset: 4, width: 5) }
        if face.pressed { border(.white, inset: 11, width: 5) }
        if let badge = face.badge { drawBadge(badge) }
        if let mark = face.mark { drawMark(mark) }
    }

    private static func symbolName(_ glyph: KeyFace.Glyph) -> String {
        switch glyph {
        case .interactOn: return "cursorarrow"
        case .interactOff: return "pencil"
        case .choose: return "hand.point.up.left.and.text"
        case .missing: return "questionmark.square.dashed"
        case .stopped: return "power"
        case .noReply: return "exclamationmark.triangle"
        case .checking: return "ellipsis"
        case .tool(let tool): return tool.symbol
        case .style, .laser: return "hand.raised.fill"
        }
    }

    private static func glyphColor(_ face: KeyFace) -> NSColor {
        switch face.tone {
        case .active: return .white
        case .idle: return NSColor(white: 0.72, alpha: 1)
        case .muted: return NSColor(white: 0.42, alpha: 1)
        case .warning: return amber
        }
    }

    static func symbol(_ name: String, in rect: CGRect, color: NSColor, inner: NSColor? = nil) {
        let configuration = NSImage.SymbolConfiguration(pointSize: rect.height * 0.86, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: inner.map { [$0, color] } ?? [color]))
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration) else { return }
        let scale = min(rect.width / image.size.width, rect.height / image.size.height, 1)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
    }

    private static func drawThumbnail(_ image: CGImage, in rect: CGRect, dimmed: Bool) {
        let scale = min(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let target = CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
        NSImage(cgImage: image, size: size).draw(in: target, from: .zero, operation: .sourceOver, fraction: dimmed ? 0.7 : 1)
    }

    private static func drawLaser(in rect: CGRect, dimmed: Bool) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let alpha: CGFloat = dimmed ? 0.65 : 1
        for (radius, opacity) in [(38.0, 0.18), (26.0, 0.35), (14.0, 1.0)] {
            NSColor.systemRed.withAlphaComponent(alpha * opacity).setFill()
            NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
        }
    }

    private static func drawLabel(_ face: KeyFace) {
        guard !face.label.isEmpty else { return }
        let color: NSColor = face.mark == .rejected ? red : face.mark == .uncertain ? amber : glyphColor(face)
        var font = NSFont.systemFont(ofSize: 24, weight: .semibold)
        var text = NSAttributedString(string: face.label, attributes: [.font: font, .foregroundColor: color])
        if text.size().width > 124 {
            font = NSFont.systemFont(ofSize: 24 * 124 / text.size().width, weight: .semibold)
            text = NSAttributedString(string: face.label, attributes: [.font: font, .foregroundColor: color])
        }
        text.draw(at: CGPoint(x: (CGFloat(side) - text.size().width) / 2, y: face.detail == nil ? 12 : 32))
        if let detail = face.detail {
            let value = NSAttributedString(string: detail, attributes: [.font: NSFont.systemFont(ofSize: 18, weight: .medium), .foregroundColor: glyphColor(face)])
            value.draw(at: CGPoint(x: (CGFloat(side) - value.size().width) / 2, y: 10))
        }
    }

    private static func border(_ color: NSColor, inset: CGFloat, width: CGFloat) {
        color.setStroke()
        let path = NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: inset, dy: inset), xRadius: 18, yRadius: 18)
        path.lineWidth = width
        path.stroke()
    }

    private static let badgeRect = CGRect(x: 98, y: 98, width: 36, height: 36)
    private static let markRect = CGRect(x: 10, y: 98, width: 36, height: 36)

    private static func drawBadge(_ badge: KeyFace.Badge) {
        switch badge {
        case .selected: symbol("checkmark", in: badgeRect, color: accent)
        case .locked: symbol("lock.fill", in: badgeRect, color: amber)
        case .busy: symbol("hourglass", in: badgeRect, color: amber)
        case .stale: symbol("arrow.clockwise", in: badgeRect, color: amber)
        }
    }

    private static func drawMark(_ mark: KeyFace.Mark) {
        switch mark {
        case .pending:
            amber.setStroke()
            let path = NSBezierPath()
            path.appendArc(withCenter: CGPoint(x: markRect.midX, y: markRect.midY), radius: 14, startAngle: 90, endAngle: 360, clockwise: false)
            path.lineWidth = 6
            path.lineCapStyle = .round
            path.stroke()
        case .accepted: symbol("arrow.right.circle.fill", in: markRect, color: green, inner: .black)
        case .rejected: symbol("xmark.octagon.fill", in: markRect, color: red, inner: .black)
        case .uncertain: symbol("questionmark.circle.fill", in: markRect, color: amber, inner: .black)
        }
    }

    /// Plugin, category and action icons. Stream Deck loads these from the manifest.
    static func writeAssets(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let icons: [(name: String, side: Int, symbol: String)] = [
            ("plugin", 288, "hand.point.up.left.fill"), ("plugin@2x", 576, "hand.point.up.left.fill"),
            ("category", 28, "hand.point.up.left"), ("category@2x", 56, "hand.point.up.left"),
            ("action-pointer", 20, "hand.point.up.left"), ("action-pointer@2x", 40, "hand.point.up.left"),
            ("action-interact", 20, "cursorarrow"), ("action-interact@2x", 40, "cursorarrow"),
            ("action-select", 20, "hand.raised"), ("action-select@2x", 40, "hand.raised"),
            ("action-tool", 20, "pencil.tip"), ("action-tool@2x", 40, "pencil.tip"),
            ("key", 72, "hand.point.up.left"), ("key@2x", 144, "hand.point.up.left")
        ]
        for icon in icons {
            let plate = icon.name.hasPrefix("plugin") || icon.name.hasPrefix("key")
            let data = render(side: icon.side, draw: {
                let bounds = CGRect(x: 0, y: 0, width: icon.side, height: icon.side)
                if plate { NSColor.black.setFill(); bounds.fill() }
                symbol(icon.symbol, in: bounds.insetBy(dx: CGFloat(icon.side) * 0.14, dy: CGFloat(icon.side) * 0.14), color: .white)
            })
            try data?.write(to: directory.appendingPathComponent(icon.name + ".png"))
        }
    }

    /// A contact sheet of every state, for visual review.
    static func writeSheet(to url: URL, thumbnail: CGImage?) throws {
        let observed = Observed(active: true, interact: true, style: "robot", accessibility: true)
        let off = Observed(active: false, interact: false, style: "lavender", accessibility: true)
        let names = ["robot": "Robot", "laser": "Laser", "lavender": "Lavender toy"]
        let select = KeySettings(style: "robot")
        func face(_ action: DeckAction, _ link: Link, _ settings: KeySettings = KeySettings(), _ transient: Transient? = nil, pressed: Bool = false) -> KeyFace {
            KeyModel.face(action: action, settings: settings, link: link, styleNames: names, transient: transient, pressed: pressed)
        }
        let faces: [KeyFace] = [
            face(.pointer, .connected(observed)), face(.pointer, .connected(off)),
            face(.interact, .connected(observed)), face(.interact, .connected(off)),
            face(.interact, .connected(Observed(active: true, interact: true, style: "robot", accessibility: false))),
            face(.selectPointer, .connected(observed), select), face(.selectPointer, .connected(off), select),
            face(.selectPointer, .connected(observed), KeySettings(style: "laser")),
            face(.selectPointer, .connected(observed)), face(.selectPointer, .connected(observed), KeySettings(style: "gone")),
            face(.pointer, .connected(off), KeySettings(), .pending, pressed: true), face(.pointer, .connected(observed), KeySettings(), .accepted, pressed: true),
            face(.interact, .connected(observed), KeySettings(), .rejected("Allow Drawing")), face(.pointer, .connected(off), KeySettings(), .uncertain),
            face(.pointer, .reconnecting(observed)), face(.pointer, .stopped), face(.pointer, .unavailable), face(.pointer, .checking)
        ]
        let columns = 6, gap = 16, rows = (faces.count + columns - 1) / columns
        let width = columns * side + (columns + 1) * gap, height = rows * side + (rows + 1) * gap
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor(white: 0.13, alpha: 1).setFill()
        CGRect(x: 0, y: 0, width: width, height: height).fill()
        for (index, item) in faces.enumerated() {
            guard let data = png(item, image: thumbnail), let key = NSImage(data: data) else { continue }
            let column = index % columns, row = index / columns
            key.draw(in: CGRect(x: gap + column * (side + gap), y: height - (row + 1) * (side + gap), width: side, height: side))
        }
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }
}
