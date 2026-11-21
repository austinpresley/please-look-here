import AppKit

/// UI order is independent of the v1 tool cycle and its saved raw values.
enum ControlTool: Equatable {
    case cursor, drawing(DrawingTool)
    static let drawingTools: [DrawingTool] = [.pen, .highlighter, .rectangle, .arrow, .text, .number, .eraser]
    static var all: [ControlTool] { [.cursor] + drawingTools.map { .drawing($0) } }
    var title: String { if case .drawing(let tool) = self { return tool.title }; return "Cursor" }
    var symbol: String { if case .drawing(let tool) = self { return tool.symbol }; return "cursorarrow" }
    var mode: PointerMode { self == .cursor ? .point : .draw }
}

struct PresentationControlsState: Equatable {
    var mode: PointerMode
    var tool: DrawingTool
    var pointerVisible: Bool
    var drawingAllowed: Bool
    var capturing: Bool = false
    var pendingDrawing = false
    var selection: ControlTool { mode == .draw || pendingDrawing ? .drawing(tool) : .cursor }
    var showsColors: Bool { selection != .cursor }
    var notReady: Bool { showsColors && (!drawingAllowed || pendingDrawing) }
    var value: String {
        if capturing { return "Taking screenshot…" }
        if notReady { return "\(tool.title) selected · Drawing needs access" }
        return "\(selection.title) · \(pointerVisible ? "Ready" : "Pointer hidden")"
    }
}

enum TapSoundState: Equatable {
    case on, pointerMuted, appMuted
    init(pointerEnabled: Bool, outputMuted: Bool) { self = outputMuted ? .appMuted : pointerEnabled ? .on : .pointerMuted }
    var symbol: String {
        switch self { case .on: return "speaker.wave.2"; case .pointerMuted: return "speaker"; case .appMuted: return "speaker.slash" }
    }
    var title: String {
        switch self { case .on: return "Tap sound on"; case .pointerMuted: return "Pointer tap sound muted"; case .appMuted: return "All app sound muted" }
    }
}

/// 8 favorites and All pointers fit the same space as 8 colors and the palette.
enum FloatingToolbarLayout {
    static let button: CGFloat = 28
    static let gap: CGFloat = 4
    static let context: CGFloat = 284
}

final class ControlIconButton: NSButton {
    // SF Symbols have different optical alignment insets. Use the common hit
    // rectangle for layout so changing tools cannot move shared controls.
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
    var selected = false { didSet { needsDisplay = true } }
    var notReady = false { didSet { needsDisplay = true } }
    private var hovering = false
    private var favoriteTitle: String?
    private var favoriteArtwork: String?
    func updateFavorite(_ style: PointerStyle) {
        let title = style.title
        let signature = style.assetName.map(HandAsset.imageSignature) ?? style.rawValue
        if favoriteArtwork != signature {
            if favoriteArtwork != nil, let asset = style.assetName { HandAsset.forget(asset) }
            image = Toolbar.icon(for: style)
            imageScaling = .scaleProportionallyUpOrDown
            favoriteArtwork = signature
        }
        if favoriteTitle != title {
            toolTip = title
            setAccessibilityLabel(title)
            favoriteTitle = title
        }
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            contentTintColor = NSColor.labelColor.usingColorSpace(.deviceRGB)
        }
        needsDisplay = true
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        if selected || hovering {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
            (selected ? ControlPalette.accent(effectiveAppearance) : NSColor.labelColor).withAlphaComponent(selected ? 0.14 : 0.07).setFill(); path.fill()
            if selected {
                ControlPalette.accent(effectiveAppearance).setStroke(); path.lineWidth = 1
                if notReady { path.setLineDash([3, 2], count: 2, phase: 0) }
                path.stroke()
            }
        }
        if title.isEmpty, let image, image.isTemplate {
            // Resolve before the NSImage drawing handler, whose offscreen
            // context otherwise defaults to Aqua for custom template artwork.
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let tint = isEnabled ? ControlPalette.foreground(effectiveAppearance)
                : NSColor(white: dark ? 0.5 : 0.55, alpha: 1)
            let tinted = NSImage(size: image.size, flipped: false) { rect in
                image.draw(in: rect); tint.setFill(); rect.fill(using: .sourceAtop); return true
            }
            let ratio = min(20 / max(1, image.size.width), 20 / max(1, image.size.height))
            let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            tinted.draw(in: CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height))
        } else { super.draw(dirtyRect) }
    }
    func updateSelection(_ selected: Bool, notReady: Bool = false) {
        self.selected = selected; self.notReady = notReady
        setAccessibilityValue(selected ? (notReady ? "Selected, drawing needs access" : "Selected") : "Not selected")
    }
}

enum ControlPalette {
    // assets/brand.json: purple in light appearance, lavender in dark.
    static func foreground(_ appearance: NSAppearance) -> NSColor {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.965, green: 0.941, blue: 0.910, alpha: 1)
            : NSColor(srgbRed: 0.188, green: 0.137, blue: 0.239, alpha: 1)
    }
    static func accent(_ appearance: NSAppearance) -> NSColor {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.788, green: 0.671, blue: 0.941, alpha: 1)
            : NSColor(srgbRed: 0.439, green: 0.314, blue: 0.627, alpha: 1)
    }
}

enum ControlArtwork {
    static func ink(_ choice: InkChoice, pointer: PointerStyle) -> NSImage? {
        if choice == .match { return Toolbar.icon(for: pointer) }
        return RadialVisualIdentity.ink(choice).image(pointer: pointer, tokens: RadialAppearance.system(NSApp.effectiveAppearance), side: 24)
    }
    static func toolPicker(_ tool: DrawingTool) -> NSImage {
        let image = NSImage(size: CGSize(width: 24, height: 24), flipped: false) { _ in
            NSImage(systemSymbolName: tool.symbol, accessibilityDescription: nil)?.draw(in: CGRect(x: 2, y: 4, width: 16, height: 18)) // grid: ok optical glyph inset
            NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?.draw(in: CGRect(x: 18, y: 2, width: 6, height: 4)) // grid: ok disclosure glyph
            return true
        }
        image.isTemplate = true; return image
    }
    /// hand.point.up.left.slash isn't available on every supported macOS.
    static func hiddenHand() -> NSImage? {
        if let image = NSImage(systemSymbolName: "hand.point.up.left.slash", accessibilityDescription: "Hide pointer") { return image }
        let image = NSImage(size: CGSize(width: 20, height: 20), flipped: false) { rect in
            NSImage(systemSymbolName: "hand.point.up.left", accessibilityDescription: nil)?.draw(in: rect.insetBy(dx: 2, dy: 2))
            NSColor.labelColor.setStroke()
            let slash = NSBezierPath(); slash.move(to: CGPoint(x: 2, y: 18)); slash.line(to: CGPoint(x: 18, y: 2)); slash.lineWidth = 2; slash.stroke()
            return true
        }
        image.isTemplate = true; return image
    }
}
