import AppKit
import QuartzCore

/// A single material and stable per-level layer tree. Movement only changes
/// opacity, ink and hub copy. The session supplies every sector axis and frame.
final class RadialRenderer: NSView {
    private final class ItemLayers {
        let fill = CAShapeLayer(), arc = CAShapeLayer(), halo = CAShapeLayer(), focus = CAShapeLayer()
        let image = CALayer(), check = CAShapeLayer(), tick = CAShapeLayer(), notch = CAShapeLayer()
        var text: [CATextLayer] = []
        var badge: CATextLayer?
        var normalImage: CGImage?, selectedImage: CGImage?
        let layout: RadialItemLayout
        init(layout: RadialItemLayout) { self.layout = layout }
    }
    private let backing = CAShapeLayer(), rim = CAShapeLayer(), hubBacking = CAShapeLayer(), separators = CAShapeLayer()
    private let foreground = CALayer(), highlights = CALayer(), focusLayer = CALayer()
    private let marker = CAShapeLayer(), markerHalo = CAShapeLayer(), armLine = CAShapeLayer()
    private var material: NSView?
    private var nodes: [ItemLayers] = []
    private var rendered = "", hubCopy = "", lastGroup: String?
    private var banks = [CALayer(), CALayer()]
    private var hubSide = 0
    private(set) var tokens = RadialAppearance()
    private(set) var layouts: [RadialItemLayout] = []
    var pointerStyle: PointerStyle = .glove
    var ink: InkChoice = .match
    var tool: DrawingTool = .pen
    private var scale: CGFloat { window?.backingScaleFactor ?? 2 }
    override var acceptsFirstResponder: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        [backing, highlights, separators, hubBacking, foreground, rim, focusLayer].forEach { layer?.addSublayer($0) }
        banks.forEach { layer?.addSublayer($0) }
        [armLine, markerHalo, marker].forEach { layer?.addSublayer($0) }
        setAccessibilityElement(true); setAccessibilityRole(.menu); setAccessibilityLabel("Quick controls")
    }
    required init?(coder: NSCoder) { fatalError() }
    override func hitTest(_ point: NSPoint) -> NSView? { self }

    func update(_ session: RadialSession, tokens: RadialAppearance) {
        self.tokens = tokens
        let holdHelp = Preferences.radialTrigger?.holdHelp ?? "Choose a held key in Shortcuts to open Quick controls."
        toolTip = holdHelp
        setAccessibilityHelp(holdHelp)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let signature = "\(pointerStyle.rawValue)/\(session.group ?? "root")/\(tokens)/\(pointerStyle.rawValue)/\(ink)/\(tool)/\(scale)"
        if signature != rendered {
            let back = lastGroup != nil && session.group == nil
            build(session)
            rendered = signature; lastGroup = session.group
            Self.fade(foreground, from: 0, to: 1, duration: tokens.levelDuration(back: back))
        }
        for (index, node) in nodes.enumerated() {
            let item = session.items[index]
            let active = session.highlighted == index && item.enabled && session.armed && !session.needNeutral && !session.outside
            let colorful = isColorful(item, session)
            Self.opacity(node.fill, active ? 1 : 0, tokens.hoverDuration)
            Self.opacity(node.arc, active && colorful ? 1 : 0, tokens.hoverDuration)
            node.focus.opacity = session.keyboard && session.highlighted == index ? 1 : 0
            node.halo.opacity = node.focus.opacity
            let color = RadialAppearance.color(!item.enabled ? tokens.secondary : (active && !colorful ? tokens.onSelection : tokens.text))
            node.image.contents = active && !colorful ? node.selectedImage : node.normalImage
            node.image.opacity = item.enabled ? 1 : 0.8
            for label in node.text { label.foregroundColor = color.cgColor }
            node.check.isHidden = !item.showsCheck
            node.tick.isHidden = node.check.isHidden
            if let badge = node.badge {
                badge.string = item.selected ? "ON" : "OFF"
                badge.backgroundColor = item.selected ? RadialAppearance.color(active ? tokens.onSelection : tokens.selection).cgColor : NSColor.clear.cgColor
                badge.foregroundColor = RadialAppearance.color(item.selected ? (active ? tokens.selection : tokens.onSelection) : (active ? tokens.onSelection : tokens.secondary)).cgColor
                badge.borderColor = RadialAppearance.color(active ? tokens.onSelection : tokens.secondary).cgColor
                badge.borderWidth = item.selected ? 0 : 1
            }
        }
        updateHub(session)
        let point = CGPoint(x: session.point.x - session.geometry.frame.minX, y: session.point.y - session.geometry.frame.minY)
        marker.path = CGPath(ellipseIn: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5), transform: nil) // grid: ok 8-point marker with opposing 1-point strokes and a 2-point open center
        let markerEdges = CGMutablePath()
        markerEdges.addEllipse(in: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7)) // grid: ok outer stroke makes the total diameter 8
        markerEdges.addEllipse(in: CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)) // grid: ok inner stroke leaves the specified 2-point opening
        markerHalo.path = markerEdges
        marker.isHidden = session.mode == .persistent; markerHalo.isHidden = marker.isHidden
        marker.fillColor = nil; marker.strokeColor = NSColor.white.cgColor; marker.lineWidth = 1
        markerHalo.fillColor = nil; markerHalo.strokeColor = NSColor.black.cgColor; markerHalo.lineWidth = 1
        let line = CGMutablePath(); line.move(to: point)
        let distance = hypot(point.x - 192, point.y - 192)
        let ratio = min(1, 56 / max(1, distance))
        line.addLine(to: CGPoint(x: 192 + (point.x - 192) * ratio, y: 192 + (point.y - 192) * ratio))
        armLine.path = line; armLine.strokeColor = RadialAppearance.color(tokens.text, alpha: 0.65).cgColor
        armLine.lineWidth = 1; armLine.lineDashPattern = [4, 4]; armLine.isHidden = session.armed || session.mode == .persistent
        CATransaction.commit()
    }
    private func build(_ session: RadialSession) {
        nodes.removeAll(); layouts.removeAll()
        [foreground, highlights, focusLayer].forEach { $0.sublayers?.forEach { $0.removeFromSuperlayer() } }
        let disc = CGRect(x: 28, y: 28, width: 328, height: 328)
        if material == nil {
            if #available(macOS 26, *) {
                let glass = NSGlassEffectView(frame: disc)
                glass.style = .regular; glass.cornerRadius = 164
                glass.contentView = NSView(frame: CGRect(origin: .zero, size: disc.size))
                material = glass
            } else {
                let effect = NSVisualEffectView(frame: disc)
                effect.material = .hudWindow; effect.blendingMode = .behindWindow; effect.state = .active
                effect.wantsLayer = true; effect.layer?.cornerRadius = 164; effect.layer?.masksToBounds = true
                material = effect
            }
            if let material {
                material.wantsLayer = true; material.layer?.zPosition = -1
                addSubview(material, positioned: .below, relativeTo: nil)
            }
        }
        material?.isHidden = !tokens.usesMaterial
        if #available(macOS 26, *), let glass = material as? NSGlassEffectView {
            glass.tintColor = RadialAppearance.color(tokens.background, alpha: 0.25)
        }
        backing.path = CGPath(ellipseIn: disc, transform: nil)
        backing.fillColor = RadialAppearance.color(tokens.background, alpha: tokens.usesMaterial ? (tokens.dark ? 0.55 : 0.65) : 1).cgColor
        backing.shadowColor = NSColor.black.cgColor; backing.shadowOpacity = tokens.dark ? 0.28 : 0.16
        backing.shadowOffset = CGSize(width: 0, height: -8); backing.shadowRadius = 20
        rim.path = CGPath(ellipseIn: disc.insetBy(dx: 0.5, dy: 0.5), transform: nil)
        rim.fillColor = nil; rim.lineWidth = tokens.contrast ? 1.5 : 1 / scale
        rim.strokeColor = RadialAppearance.color(tokens.text, alpha: tokens.contrast ? 1 : 0.2).cgColor
        hubBacking.path = CGPath(ellipseIn: CGRect(x: 136, y: 136, width: 112, height: 112), transform: nil)
        hubBacking.fillColor = RadialAppearance.color(tokens.dark ? 0xF6F0E8 : 0xFFFFFF, alpha: tokens.dark ? 0.06 : 0.55).cgColor
        hubBacking.strokeColor = RadialAppearance.color(tokens.text, alpha: 0.12).cgColor; hubBacking.lineWidth = 1 / scale
        let separator = CGMutablePath()
        let width = 360 / CGFloat(session.items.count)
        for (index, item) in session.items.enumerated() {
            let angle = session.angle(for: index)
            separator.move(to: Self.point(angle + width / 2, 70)); separator.addLine(to: Self.point(angle + width / 2, 156))
            let layout = RadialItemLayout(session: session, index: index)
            let node = ItemLayers(layout: layout); layouts.append(layout); nodes.append(node)
            node.fill.path = Self.sector(67, 160, angle - width / 2, angle + width / 2)
            node.fill.fillColor = RadialAppearance.color(tokens.selection, alpha: isColorful(item, session) ? (tokens.dark ? 0.2 : 0.13) : 1).cgColor
            node.arc.path = Self.sector(158, 160, angle - width / 2 + 1, angle + width / 2 - 1, corner: 1)
            node.arc.fillColor = RadialAppearance.color(tokens.selection).cgColor
            highlights.addSublayer(node.fill); highlights.addSublayer(node.arc)
            for outline in [node.halo, node.focus] {
                outline.path = Self.sector(64.5, 162.5, angle - width / 2, angle + width / 2, corner: 3, gap: 0.5)
                outline.fillColor = nil; outline.lineJoin = .round; focusLayer.addSublayer(outline)
            }
            node.halo.strokeColor = RadialAppearance.color(tokens.dark ? tokens.background : 0xFFFFFF).cgColor
            node.halo.lineWidth = tokens.contrast ? 5 : 4
            node.focus.strokeColor = NSColor.systemBlue.cgColor; node.focus.lineWidth = 2
            node.image.frame = layout.icon;
            node.image.setAffineTransform(item.isBack ? CGAffineTransform(rotationAngle: -angle * .pi / 180) : .identity); node.image.contentsGravity = .resizeAspect; node.image.contentsScale = scale
            node.normalImage = artwork(item, session: session, color: RadialAppearance.color(item.enabled ? tokens.text : tokens.secondary), side: layout.icon.width)
            node.selectedImage = artwork(item, session: session, color: RadialAppearance.color(tokens.onSelection), side: layout.icon.width)
            foreground.addSublayer(node.image)
            node.text = layout.labels.map { line, rect in
                let label = Self.text(line, frame: rect, size: layout.fontSize, weight: .medium, color: RadialAppearance.color(tokens.text), scale: scale)
                foreground.addSublayer(label); return label
            }
            if let rect = layout.badge {
                let badge = Self.text("OFF", frame: rect, size: 11, weight: .semibold, color: RadialAppearance.color(tokens.secondary), scale: scale)
                badge.cornerRadius = 8; badge.masksToBounds = true; foreground.addSublayer(badge); node.badge = badge
            }
            let checkCenter = CGPoint(x: layout.check.midX, y: layout.check.midY)
            node.check.path = CGPath(ellipseIn: layout.check, transform: nil)
            node.check.fillColor = NSColor.white.cgColor; node.check.strokeColor = NSColor.black.withAlphaComponent(0.3).cgColor; node.check.lineWidth = 1
            let tick = CGMutablePath(); tick.move(to: CGPoint(x: checkCenter.x - 3.2, y: checkCenter.y)); tick.addLine(to: CGPoint(x: checkCenter.x - 1.1, y: checkCenter.y - 2.1)); tick.addLine(to: CGPoint(x: checkCenter.x + 3, y: checkCenter.y + 2.2))
            node.tick.path = tick; node.tick.fillColor = nil; node.tick.strokeColor = RadialAppearance.color(0x9E3A33).cgColor; node.tick.lineWidth = 1.9; node.tick.lineCap = .round; node.tick.lineJoin = .round
            foreground.addSublayer(node.check); foreground.addSublayer(node.tick)
            if item.role.opensSubmenu {
                node.notch.path = Self.sector(160.5, 162.5, angle - 8, angle + 8, corner: 1, gap: 0)
                node.notch.fillColor = RadialAppearance.color(tokens.secondary, alpha: 0.55).cgColor; foreground.addSublayer(node.notch)
            }
        }
        separators.path = separator; separators.fillColor = nil
        separators.strokeColor = RadialAppearance.color(tokens.text, alpha: tokens.contrast ? 0.5 : 0.12).cgColor
        separators.lineWidth = tokens.contrast ? 1 : 1 / scale
        hubCopy = ""
    }
    private func isColorful(_ item: RadialItem, _ session: RadialSession) -> Bool {
        RadialVisualIdentity.resolve(item, pointer: pointerStyle, ink: ink, tool: tool).colorful
    }
    private func artwork(_ item: RadialItem, session: RadialSession, color: NSColor, side: CGFloat) -> CGImage? {
        let identity = RadialVisualIdentity.resolve(item, pointer: pointerStyle, ink: ink, tool: tool)
        let source = identity.image(pointer: pointerStyle, tokens: tokens, side: side)
        let image = identity.colorful ? source : source?.withSymbolConfiguration(.init(pointSize: side, weight: .medium))
        guard let image else { return nil }
        let art = isColorful(item, session)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(side * scale), pixelsHigh: Int(side * scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = CGSize(width: side, height: side)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        let ratio = min(side / max(1, image.size.width), side / max(1, image.size.height))
        let fitted = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        image.draw(in: CGRect(x: (side - fitted.width) / 2, y: (side - fitted.height) / 2, width: fitted.width, height: fitted.height), from: .zero, operation: .sourceOver, fraction: 1)
        if !art { color.setFill(); rect.fill(using: .sourceAtop) }
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }
    private func updateHub(_ session: RadialSession) {
        let copy = session.pendingCopy
        let signature = "\(copy.title)/\(copy.subtitle)/\(session.group ?? "root")/\(session.highlighted ?? -1)/\(String(describing: session.inspected?.role))"
        guard signature != hubCopy else { return }; hubCopy = signature
        let previous = banks[hubSide]; hubSide = 1 - hubSide; let bank = banks[hubSide]
        bank.sublayers?.forEach { $0.removeFromSuperlayer() }
        if session.group == nil && (!session.armed || session.needNeutral || session.outside || session.inspected == nil) {
            let hand = CALayer(); hand.frame = CGRect(x: 172, y: 184, width: 40, height: 40)
            hand.contentsGravity = .resizeAspect
            if let image = Toolbar.icon(for: pointerStyle) { hand.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil) }
            bank.addSublayer(hand)
            bank.addSublayer(Self.text("esc", frame: CGRect(x: 176, y: 160, width: 32, height: 16), size: 11, weight: .regular, color: RadialAppearance.color(tokens.secondary), scale: scale))
            Self.opacity(previous, 0, tokens.hubDuration); Self.opacity(bank, 1, tokens.hubDuration)
            return
        }
        let titles = RadialItemLayout.wrap(copy.title, font: .systemFont(ofSize: 13, weight: .semibold), width: 96)
        let subtitles = RadialItemLayout.wrap(copy.subtitle, font: .systemFont(ofSize: 11), width: 96)
        let art = session.armed && !session.needNeutral && !session.outside ? session.inspected : nil
        var top: CGFloat
        if let art {
            let height = 28 + 6 + CGFloat(titles.count) * 16 + (subtitles.isEmpty ? 0 : 2 + CGFloat(subtitles.count) * 14)
            top = 192 + height / 2
            let image = CALayer(); image.frame = CGRect(x: 178, y: top - 28, width: 28, height: 28); image.contentsGravity = .resizeAspect
            image.contents = artwork(art, session: session, color: RadialAppearance.color(art.enabled ? tokens.text : tokens.secondary), side: 28)
            if art.isBack, let index = session.items.firstIndex(where: { $0.isBack }) {
                image.setAffineTransform(CGAffineTransform(rotationAngle: -session.angle(for: index) * .pi / 180))
            }
            bank.addSublayer(image); top -= 34
        } else { top = 206 + CGFloat(titles.count) * 16 }
        for title in titles {
            top -= 16
            bank.addSublayer(Self.text(title, frame: CGRect(x: 144, y: top, width: 96, height: 16), size: 13, weight: .semibold, color: RadialAppearance.color(tokens.text), scale: scale))
        }
        top = art == nil ? 178 : top - 2
        for subtitle in subtitles {
            top -= 14
            bank.addSublayer(Self.text(subtitle, frame: CGRect(x: 144, y: top, width: 96, height: 14), size: 11, weight: .regular, color: RadialAppearance.color(tokens.secondary), scale: scale)) // grid: ok v9 11/14 hub subtitle leading
        }
        Self.opacity(previous, 0, tokens.hubDuration); Self.opacity(bank, 1, tokens.hubDuration)
    }
    static func text(_ string: String, frame: CGRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, scale: CGFloat) -> CATextLayer {
        let layer = CATextLayer(); layer.frame = frame; layer.string = string
        layer.font = NSFont.systemFont(ofSize: size, weight: weight); layer.fontSize = size
        layer.alignmentMode = .center; layer.foregroundColor = color.cgColor; layer.contentsScale = scale
        layer.truncationMode = .end
        return layer
    }
    static func point(_ angle: CGFloat, _ radius: CGFloat) -> CGPoint { RadialGeometry.point(angle: angle, radius: radius, center: CGPoint(x: 192, y: 192)) }
    static func sector(_ inner: CGFloat, _ outer: CGFloat, _ start: CGFloat, _ end: CGFloat, corner: CGFloat = 2, gap: CGFloat = 2) -> CGPath {
        let a0 = start + gap / 164 * 180 / .pi, a1 = end - gap / 164 * 180 / .pi
        let od = corner / outer * 180 / .pi, id = corner / inner * 180 / .pi
        let path = CGMutablePath(); path.move(to: point(a0 + od, outer))
        path.addArc(center: CGPoint(x: 192, y: 192), radius: outer, startAngle: (90 - a0 - od) * .pi / 180, endAngle: (90 - a1 + od) * .pi / 180, clockwise: true)
        path.addQuadCurve(to: point(a1, outer - corner), control: point(a1, outer))
        path.addLine(to: point(a1, inner + corner)); path.addQuadCurve(to: point(a1 - id, inner), control: point(a1, inner))
        path.addArc(center: CGPoint(x: 192, y: 192), radius: inner, startAngle: (90 - a1 + id) * .pi / 180, endAngle: (90 - a0 - id) * .pi / 180, clockwise: false)
        path.addQuadCurve(to: point(a0, inner + corner), control: point(a0, inner)); path.addLine(to: point(a0, outer - corner))
        path.addQuadCurve(to: point(a0 + od, outer), control: point(a0, outer)); path.closeSubpath(); return path
    }
    static func fade(_ layer: CALayer, from: Float, to: Float, duration: TimeInterval) {
        layer.opacity = to
        guard duration > 0 else { layer.removeAnimation(forKey: "opacity"); return }
        let animation = CABasicAnimation(keyPath: "opacity"); animation.fromValue = from; animation.toValue = to; animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1); layer.add(animation, forKey: "opacity")
    }
    private static func opacity(_ layer: CALayer, _ value: Float, _ duration: TimeInterval) {
        guard layer.opacity != value else { return }
        fade(layer, from: layer.presentation()?.opacity ?? layer.opacity, to: value, duration: duration)
    }
}
