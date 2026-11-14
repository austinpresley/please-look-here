import AppKit

enum PointerMode: String, CaseIterable {
    case point, draw
    // Preserve stored values and protocol v1 clients while presenting one Interact toggle.
    var isInteractive: Bool { self == .point }
    var title: String { isInteractive ? "Interact On" : "Interact Off" }

    func hidesPointer(whilePressing pressing: Bool, keepsHand: Bool) -> Bool {
        isInteractive && pressing && !keepsHand
    }
}

enum DrawingTool: String, CaseIterable {
    case pen, rectangle, arrow, text, number
    /// Protocol and toolbar order. Always wrap, including Number back to Pen.
    var next: DrawingTool { Self.allCases[(Self.allCases.firstIndex(of: self)! + 1) % Self.allCases.count] }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .rectangle: return "rectangle"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .number: return "number.circle"
        }
    }
    var key: String {
        switch self {
        case .pen: return "F"
        case .rectangle: return "R"
        case .arrow: return "A"
        case .text: return "T"
        case .number: return "N"
        }
    }
}

enum StrokeSmoothing: Int, CaseIterable {
    case off, veryLight, light, medium
    var title: String { ["Off", "Very light", "Light", "Medium"][rawValue] }
    var radius: Int { [0, 1, 2, 4][rawValue] }
}

struct AnnotationColor: Equatable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    init(_ color: CGColor) {
        let c = NSColor(cgColor: color)?.usingColorSpace(.deviceRGB) ?? .systemPurple
        red = c.redComponent
        green = c.greenComponent
        blue = c.blueComponent
    }
    func cgColor(opacity: CGFloat) -> CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: opacity)
    }
    var contrastingText: CGColor {
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.6 ? NSColor.black.cgColor : NSColor.white.cgColor
    }
}

struct AnnotationStyle: Equatable {
    var color: AnnotationColor
    var width: CGFloat
    var opacity: CGFloat
    var smoothing: StrokeSmoothing
}

struct Annotation: Equatable, Identifiable {
    enum Shape: Equatable {
        case pen([CGPoint])
        case rectangle(CGPoint, CGPoint)
        case arrow(CGPoint, CGPoint)
        case text(String, CGPoint)
        case number(Int, CGPoint)
    }
    var id = UUID()
    var shape: Shape
    var style: AnnotationStyle
    var markerRadius: CGFloat { max(16, style.width * 2) }
    var isMeaningful: Bool {
        switch shape {
        case .pen(let points): return points.count > 1
        case .rectangle(let a, let b): return abs(a.x - b.x) >= 2 && abs(a.y - b.y) >= 2
        case .arrow(let a, let b): return hypot(a.x - b.x, a.y - b.y) >= 4
        case .text(let text, _): return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .number: return true
        }
    }
}

/// Value geometry and edit history, independent of event taps and windows.
struct AnnotationDocument {
    private(set) var annotations: [Annotation] = []
    private var history: [[Annotation]] = []
    private var future: [[Annotation]] = []
    var canUndo: Bool { !history.isEmpty }
    var canRedo: Bool { !future.isEmpty }
    var nextNumber: Int {
        (annotations.compactMap { if case .number(let n, _) = $0.shape { return n }; return nil }.max() ?? 0) + 1
    }
    mutating func append(_ annotation: Annotation) {
        guard annotation.isMeaningful else { return }
        checkpoint()
        annotations.append(annotation)
    }
    mutating func replace(_ annotation: Annotation) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }), annotations[index] != annotation else { return }
        checkpoint()
        annotations[index] = annotation
    }
    mutating func remove(_ id: UUID) {
        guard annotations.contains(where: { $0.id == id }) else { return }
        checkpoint()
        annotations.removeAll { $0.id == id }
    }
    mutating func clear() {
        guard !annotations.isEmpty else { return }
        checkpoint()
        annotations.removeAll()
    }
    mutating func undo() {
        guard let previous = history.popLast() else { return }
        future.append(annotations)
        annotations = previous
    }
    mutating func redo() {
        guard let next = future.popLast() else { return }
        history.append(annotations)
        annotations = next
    }
    mutating func reset() { self = AnnotationDocument() }
    func marker(at point: CGPoint) -> Annotation? {
        annotations.reversed().first {
            guard case .number(_, let center) = $0.shape else { return false }
            return hypot(center.x - point.x, center.y - point.y) <= $0.markerRadius + 4
        }
    }
    private mutating func checkpoint() {
        history.append(annotations)
        if history.count > 100 { history.removeFirst() }
        future.removeAll()
    }
}

enum AnnotationGeometry {
    /// Neighbor-weighted smoothing keeps endpoints at their real input locations.
    static func smooth(_ points: [CGPoint], strength: StrokeSmoothing) -> [CGPoint] {
        let radius = strength.radius
        guard radius > 0, points.count > 2 else { return points }
        return points.indices.map { i in
            guard i > 0, i < points.count - 1 else { return points[i] }
            var x: CGFloat = 0, y: CGFloat = 0, total: CGFloat = 0
            for j in max(0, i - radius)...min(points.count - 1, i + radius) {
                let weight = CGFloat(radius + 1 - abs(j - i))
                x += points[j].x * weight
                y += points[j].y * weight
                total += weight
            }
            return CGPoint(x: x / total, y: y / total)
        }
    }
    static func path(_ annotation: Annotation) -> CGPath {
        let path = CGMutablePath()
        switch annotation.shape {
        case .pen(let raw):
            let points = smooth(raw, strength: annotation.style.smoothing)
            guard let first = points.first else { return path }
            path.move(to: first)
            if points.count > 1 {
                for i in 1..<points.count {
                    let previous = points[i - 1], current = points[i]
                    path.addQuadCurve(to: CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2), control: previous)
                }
                path.addLine(to: points[points.count - 1])
            }
        case .rectangle(let a, let b):
            path.addRect(CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y)))
        case .arrow(let a, let b):
            path.move(to: a)
            path.addLine(to: b)
            let angle = atan2(b.y - a.y, b.x - a.x)
            let length = min(hypot(b.x - a.x, b.y - a.y) * 0.4, max(12, annotation.style.width * 3))
            for side: CGFloat in [-1, 1] {
                path.move(to: b)
                path.addLine(to: CGPoint(x: b.x - length * cos(angle + side * .pi / 6), y: b.y - length * sin(angle + side * .pi / 6)))
            }
        case .number(_, let center):
            let r = annotation.markerRadius
            path.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        case .text: break
        }
        return path
    }
}
