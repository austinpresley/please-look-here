import AppKit

/// Keeps one undo entry per completed annotation gesture.
final class Ink {
    let layer = CALayer()
    private(set) var document = AnnotationDocument()
    private var draft: Annotation?
    private var editingMarker: Annotation?
    private var eraserPress = false
    private var erasing: UUID?
    private var pressPoint: CGPoint?
    private var markerOffset = CGPoint.zero
    private var changedMarker = false
    private var rendered: [UUID: (Annotation, CALayer)] = [:]
    private var visibility = InkVisibility()
    private var trailTimer: Timer?
    private let clock: () -> TimeInterval
    private let lifetimePolicy: () -> InkLifetimePolicy
    init(clock: @escaping () -> TimeInterval = { CACurrentMediaTime() },
         lifetimePolicy: @escaping () -> InkLifetimePolicy = { .current }) {
        self.clock = clock; self.lifetimePolicy = lifetimePolicy
    }
    deinit { trailTimer?.invalidate() }
    var onChanged: (() -> Void)?
    var color = Ink.purple
    var scale: CGFloat = 2 {
        didSet {
            guard scale != oldValue else { return }
            func update(_ layer: CALayer) {
                layer.contentsScale = scale
                layer.sublayers?.forEach(update)
            }
            update(layer)
        }
    }
    var tool: DrawingTool = .pen
    var opacity: CGFloat = 1
    var smoothing: StrokeSmoothing = .light
    var hasActiveTrails: Bool { visibility.hasActiveTrails }
    var isDrawing: Bool { draft != nil || editingMarker != nil || eraserPress }
    var canUndo: Bool { document.canUndo }
    var canRedo: Bool { document.canRedo }
    var count: Int {
        refreshVisibility()
        return document.annotations.filter { visibility.state(for: $0.id).visible }.count
    }

    static let purple = CGColor(srgbRed: 0.53, green: 0.33, blue: 0.95, alpha: 1)
    static let red = CGColor(srgbRed: 1, green: 0.16, blue: 0.12, alpha: 1)
    static func hex(_ v: UInt32) -> CGColor {
        CGColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
                blue: CGFloat(v & 255) / 255, alpha: 1)
    }

    func begin(at point: CGPoint, width: CGFloat) {
        cancel()
        pressPoint = point
        var style = AnnotationStyle(color: AnnotationColor(color), width: width, opacity: opacity, smoothing: smoothing)
        if tool == .highlighter {
            style.width *= 3
            style.opacity *= 0.35
            style.isHighlighter = true
        }
        refreshVisibility()
        if tool == .eraser {
            eraserPress = true
            erasing = AnnotationHitTest.topmost(at: point, in: document.annotations, visibility: { self.visibility.state(for: $0) })?.id
            return
        }
        if tool == .number, let marker = document.marker(at: point, visible: { self.visibility.state(for: $0).visible }), case .number(_, let center) = marker.shape {
            editingMarker = marker
            markerOffset = CGPoint(x: center.x - point.x, y: center.y - point.y)
            changedMarker = false
            return
        }
        let shape: Annotation.Shape
        switch tool {
        case .pen, .highlighter: shape = .pen([point])
        case .rectangle: shape = .rectangle(point, point)
        case .arrow: shape = .arrow(point, point)
        case .number: shape = .number(document.nextNumber, point)
        case .text, .eraser: return
        }
        draft = Annotation(shape: shape, style: style)
        if let draft { visibility.begin(draft, at: clock(), policy: lifetimePolicy()) }
        render()
    }

    func extend(to point: CGPoint) {
        if var marker = editingMarker, case .number(let n, _) = marker.shape {
            if let start = pressPoint, hypot(point.x - start.x, point.y - start.y) > 3 { changedMarker = true }
            if changedMarker {
                marker.shape = .number(n, CGPoint(x: point.x + markerOffset.x, y: point.y + markerOffset.y))
                editingMarker = marker
                render()
            }
            return
        }
        guard var annotation = draft else { return }
        switch annotation.shape {
        case .pen(var points):
            guard let last = points.last, hypot(point.x - last.x, point.y - last.y) >= 1.5 else { return }
            points.append(point)
            annotation.shape = .pen(points)
            visibility.append(point, to: annotation.id, at: clock())
        case .rectangle(let a, _): annotation.shape = .rectangle(a, point)
        case .arrow(let a, _): annotation.shape = .arrow(a, point)
        case .number(let n, _): annotation.shape = .number(n, point)
        case .text: break
        }
        draft = annotation
        render()
    }

    func end() {
        if eraserPress {
            refreshVisibility()
            let before = document.annotations
            if let erasing, visibility.state(for: erasing).visible { document.remove(erasing) }
            visibility.reconcile(from: before, to: document.annotations, at: clock(), policy: lifetimePolicy())
        } else if let marker = editingMarker {
            let before = document.annotations
            if changedMarker { document.replace(marker) } else { document.remove(marker.id) }
            visibility.reconcile(from: before, to: document.annotations, at: clock(), policy: lifetimePolicy())
        } else if let annotation = draft, annotation.isMeaningful {
            document.append(annotation)
            visibility.finish(annotation.id, at: clock())
        } else if let draft { visibility.remove(draft.id) }
        draft = nil
        editingMarker = nil
        eraserPress = false
        erasing = nil
        pressPoint = nil
        render()
        onChanged?()
    }

    func addText(_ text: String, at point: CGPoint, width: CGFloat) {
        let style = AnnotationStyle(color: AnnotationColor(color), width: width, opacity: opacity, smoothing: smoothing)
        edit { $0.append(Annotation(shape: .text(text, point), style: style)) }
    }
    func cancel() {
        if let draft { visibility.remove(draft.id) }
        draft = nil
        editingMarker = nil
        eraserPress = false
        erasing = nil
        pressPoint = nil
        render()
    }
    private func edit(_ action: (inout AnnotationDocument) -> Void) {
        cancel()
        let before = document.annotations
        action(&document)
        visibility.reconcile(from: before, to: document.annotations, at: clock(), policy: lifetimePolicy())
        render()
        onChanged?()
    }
    func undo() { edit { $0.undo() } }
    func redo() { edit { $0.redo() } }
    func clear() { edit { $0.clear() } }
    func reset() { edit { $0.reset() } }

    private func render() {
        var items = document.annotations
        if let marker = editingMarker, let i = items.firstIndex(where: { $0.id == marker.id }) { items[i] = marker }
        if let draft = draft { items.append(draft) }
        let ids = Set(items.map(\.id))
        for id in rendered.keys.filter({ !ids.contains($0) }) {
            rendered.removeValue(forKey: id)?.1.removeFromSuperlayer()
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for item in items {
            if let existing = rendered[item.id], existing.0 == item { continue }
            let replacement = makeLayer(item)
            if let previous = rendered[item.id]?.1 {
                layer.replaceSublayer(previous, with: replacement)
            } else { layer.addSublayer(replacement) }
            rendered[item.id] = (item, replacement)
        }
        layer.sublayers = items.compactMap { rendered[$0.id]?.1 }
        CATransaction.commit()
        refreshVisibility()
    }

    private func startTrailTimer() {
        guard trailTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.advanceTrails() }
        RunLoop.main.add(timer, forMode: .common)
        trailTimer = timer
    }
    // Kept as the existing deterministic clock-advance entry point for tests.
    func advanceTrails() { refreshVisibility() }
    private func refreshVisibility() {
        let before = document.annotations.filter { visibility.state(for: $0.id).visible }.count
        visibility.advance(to: clock())
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for (id, entry) in rendered {
            let state = visibility.state(for: id)
            entry.1.opacity = Float(state.opacity)
            if let shape = entry.1 as? CAShapeLayer { shape.strokeStart = state.strokeStart }
        }
        CATransaction.commit()
        if visibility.needsClock { startTrailTimer() }
        else { trailTimer?.invalidate(); trailTimer = nil }
        if before != document.annotations.filter({ visibility.state(for: $0.id).visible }).count { onChanged?() }
    }

    private func makeLayer(_ annotation: Annotation) -> CALayer {
        let style = annotation.style
        if case .text(let text, let point) = annotation.shape {
            return textLayer(text, point: point, fontSize: max(16, style.width * 3), color: style.color.cgColor(opacity: style.opacity))
        }
        let shape = CAShapeLayer()
        shape.path = AnnotationGeometry.path(annotation)
        shape.strokeColor = style.color.cgColor(opacity: style.opacity)
        shape.fillColor = nil
        shape.lineWidth = style.width
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.contentsScale = scale
        if case .number(let n, let center) = annotation.shape {
            shape.fillColor = style.color.cgColor(opacity: style.opacity)
            shape.strokeColor = NSColor.black.withAlphaComponent(0.15 * style.opacity).cgColor
            shape.lineWidth = 1
            let fontSize = annotation.markerRadius * 1.1
            let label = textLayer(String(n), point: center, fontSize: fontSize, color: style.color.contrastingText)
            label.opacity = Float(style.opacity)
            label.position = CGPoint(x: center.x - label.bounds.width / 2, y: center.y - label.bounds.height / 2)
            shape.addSublayer(label)
        }
        return shape
    }

    private func textLayer(_ text: String, point: CGPoint, fontSize: CGFloat, color: CGColor) -> CATextLayer {
        let label = CATextLayer()
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        label.string = text
        label.font = font
        label.fontSize = fontSize
        label.foregroundColor = color
        label.contentsScale = scale
        label.anchorPoint = .zero
        label.frame = AnnotationGeometry.textBounds(text, at: point, fontSize: fontSize)
        return label
    }
}
