import AppKit

/// Shared artwork identity for wheel, hub and small-display rows.
enum RadialVisualIdentity: Equatable {
    case pointer(PointerStyle), ink(InkChoice), symbol(String)

    static func resolve(_ item: RadialItem, pointer: PointerStyle, ink: InkChoice, tool: DrawingTool, list: Bool = false) -> Self {
        switch item.role {
        case .pointerFavorite:
            return item.style.map { .pointer($0) } ?? .symbol(item.symbol)
        case .root(.pointer): return .pointer(pointer)
        case .root(.color): return .symbol("paintpalette")
        case .root(.draw): return .symbol(tool.symbol)
        case .ink(let choice): return .ink(choice)
        case .back: return .symbol(list ? "arrow.left" : "arrow.up")
        default: return .symbol(item.symbol)
        }
    }
    var colorful: Bool { if case .symbol = self { return false }; return true }
    func image(pointer: PointerStyle, tokens: RadialAppearance, side: CGFloat = 32) -> NSImage? {
        switch self {
        case .pointer(let style): return Toolbar.icon(for: style)
        case .symbol(let name): return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        case .ink(let choice):
            return NSImage(size: CGSize(width: 32, height: 32), flipped: false) { rect in
                NSColor(cgColor: choice.resolved(for: pointer))?.setFill()
                let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4)); circle.fill()
                // A light rim on dark and a dark rim on light preserves black/white.
                RadialAppearance.color(tokens.dark ? 0xF6F0E8 : 0x493F50, alpha: tokens.contrast ? 1 : 0.65).setStroke()
                circle.lineWidth = (tokens.contrast ? 2 : 1) * 32 / side; circle.stroke()
                if choice == .match {
                    RadialAppearance.color(tokens.background).setFill()
                    NSBezierPath(ovalIn: CGRect(x: 16, y: 16, width: 16, height: 16)).fill()
                    Toolbar.icon(for: pointer)?.draw(in: CGRect(x: 17, y: 17, width: 14, height: 14)) // grid: ok mini hand optical inset
                }
                return true
            }
        }
    }
    static func rowState(_ item: RadialItem) -> String {
        item.role.hasStateBadge ? (item.selected ? "ON" : "OFF") : item.role.opensSubmenu ? "›" : item.showsCheck ? "✓" : ""
    }
}
