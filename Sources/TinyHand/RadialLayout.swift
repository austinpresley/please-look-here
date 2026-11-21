import AppKit

struct RadialListLayout {
    static let rowHeight: CGFloat = 28
    static let headerHeight: CGFloat = 44
    let frame: CGRect
    let count: Int
    var viewportHeight: CGFloat { max(0, frame.height - Self.headerHeight - 8) }
    var maximumScroll: CGFloat { max(0, CGFloat(count) * Self.rowHeight - viewportHeight) }
    init(bounds: CGRect, center: CGPoint, count: Int) {
        self.count = count
        let size = CGSize(width: min(300, max(0, bounds.width - 24)), height: min(CGFloat(count) * Self.rowHeight + Self.headerHeight + 8, max(0, bounds.height - 24)))
        frame = CGRect(x: min(max(center.x - size.width / 2, bounds.minX + 12), bounds.maxX - size.width - 12),
                       y: min(max(center.y - size.height / 2, bounds.minY + 12), bounds.maxY - size.height - 12), width: size.width, height: size.height)
    }
    func index(at point: CGPoint, scroll: CGFloat) -> Int? {
        let y = frame.maxY - Self.headerHeight - point.y
        guard point.x >= frame.minX + 8, point.x <= frame.maxX - 8, y >= 0, y < viewportHeight else { return nil }
        let index = Int(floor((y + scroll) / Self.rowHeight))
        return (0..<count).contains(index) ? index : nil
    }
    func row(_ index: Int, scroll: CGFloat = 0) -> CGRect {
        CGRect(x: 8, y: frame.height - Self.headerHeight - CGFloat(index + 1) * Self.rowHeight + scroll, width: frame.width - 16, height: Self.rowHeight)
    }
}

struct RadialAppearance: Equatable {
    var dark = false
    var opaque = false
    var contrast = false
    var reduceMotion = false
    var background: UInt32 { dark ? 0x29242D : 0xF8F5F1 }
    var text: UInt32 { dark ? 0xF6F0E8 : 0x302736 }
    var secondary: UInt32 { dark ? 0xC3B9C8 : 0x645B68 }
    var selection: UInt32 { dark ? 0xFF9589 : 0xB6423B }
    var onSelection: UInt32 { dark ? 0x302736 : 0xFFFFFF }
    var usesMaterial: Bool { !opaque && !contrast }
    var openDuration: TimeInterval { reduceMotion ? 0.08 : 0.12 }
    var hoverDuration: TimeInterval { reduceMotion ? 0 : 0.06 }
    var hubDuration: TimeInterval { reduceMotion ? 0 : 0.08 }
    func levelDuration(back: Bool) -> TimeInterval { reduceMotion ? 0 : (back ? 0.08 : 0.1) }
    var closeDuration: TimeInterval { reduceMotion ? 0 : 0.08 }
    static func system(_ appearance: NSAppearance) -> Self {
        Self(dark: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua,
             opaque: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
             contrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
             reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
    static func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
}

/// Measured visible frames, shared by the renderer, accessibility and probes.
/// All angular positions come from RadialSession, never from a second hit map.
struct RadialItemLayout {
    let icon: CGRect
    let labels: [(String, CGRect)]
    let badge: CGRect?
    let fontSize: CGFloat
    let leading: CGFloat
    let showsCheck: Bool
    var check: CGRect { CGRect(x: icon.maxX - 5, y: icon.minY - 5, width: 14, height: 14) } // grid: ok v9 14-point check badge
    var visibleFrames: [CGRect] { [icon] + labels.map(\.1) + (badge.map { [$0] } ?? []) + (showsCheck ? [check] : []) }
    var frame: CGRect { visibleFrames.reduce(CGRect.null) { $0.union($1) } }
    static func wrap(_ text: String, font: NSFont, width: CGFloat) -> [String] {
        var lines: [String] = []; var line = ""
        for word in text.split(separator: " ") {
            let next = line.isEmpty ? String(word) : line + " " + word
            if !line.isEmpty && (next as NSString).size(withAttributes: [.font: font]).width > width { lines.append(line); line = String(word) }
            else { line = next }
        }
        if !line.isEmpty { lines.append(line) }
        // Keep full source copy in the last line. CATextLayer truncates that
        // exceptional long-name line by measured width; AX retains the name.
        return lines.count > 2 ? [lines[0], lines.dropFirst().joined(separator: " ")] : lines
    }
    init(session: RadialSession, index: Int) {
        let item = session.items[index], child = session.group != nil
        showsCheck = item.showsCheck
        fontSize = child ? 12 : 13; leading = child ? 15 : 16
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let lines = Self.wrap(item.title, font: font, width: child ? 64 : 76)
        let art: Bool
        switch item.role {
        case .root(.pointer): art = true
        case .pointerFavorite: art = item.style != nil
        default: art = false
        }
        let side: CGFloat = art ? 32 : (child ? 22 : 24)
        let badgeHeight: CGFloat = item.role.hasStateBadge ? 20 : 0
        let height = side + 8 + CGFloat(lines.count) * leading + badgeHeight
        let radius = RadialGeometry.rootRadius - (lines.count > 1 ? 4 : 0) - (item.role == .root(.screenshot) ? 6 : 0)
        var center = RadialGeometry.point(angle: session.angle(for: index), radius: radius, center: CGPoint(x: 192, y: 192))
        // AppKit's measured block needs one additional point outward at this
        // ten-sector axis to retain the specified 4-point upward correction.
        if item.role == .ink(.match) { center.y += 4; center.x -= 1 }
        let top = center.y + height / 2
        icon = CGRect(x: center.x - side / 2, y: top - side, width: side, height: side)
        let lineHeight = leading
        labels = lines.enumerated().map { i, text in
            let measured = ceil((text as NSString).size(withAttributes: [.font: font]).width)
            // The wrapping width is not a clipping width. Native "Highlighter"
            // measures 64.33 pt and fits its sector in a 65-point text frame.
            var width = measured <= (child ? 76 : 88) ? measured : min(measured, child ? 64 : 76)
            let y = top - side - 8 - CGFloat(i + 1) * lineHeight
            // Missing/custom names can be arbitrarily long. Keep native type
            // size and fit their text frame to this sector before truncating.
            func fits(_ width: CGFloat) -> Bool {
                [center.x - width / 2, center.x + width / 2].allSatisfy { x in
                    [y, y + lineHeight].allSatisfy { y in
                        let point = CGPoint(x: x, y: y), origin = CGPoint(x: 192, y: 192)
                        return RadialGeometry.distance(point, origin) <= 156 + RadialGeometry.roundingTolerance
                            && RadialGeometry.difference(RadialGeometry.angle(point, from: origin), session.angle(for: index)) <= 180 / CGFloat(session.items.count)
                    }
                }
            }
            while width > 0 && !fits(width) { width = max(0, width - 1) }
            return (text, CGRect(x: center.x - width / 2, y: y, width: width, height: lineHeight))
        }
        badge = badgeHeight == 0 ? nil : CGRect(x: center.x - 17, y: center.y - height / 2, width: 34, height: 16) // grid: ok v9 ON/OFF pill dimensions
    }
}
