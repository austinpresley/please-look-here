import AppKit

/// Keeps one undo entry per completed annotation gesture.
final class Ink {
    let layer = CALayer()
    private(set) var document = AnnotationDocument()
    private var draft: Annotation?
    private var editingMarker: Annotation?
    private var pressPoint: CGPoint?
    private var markerOffset = CGPoint.zero
    private var changedMarker = false
    private var rendered: [UUID: (Annotation, CALayer)] = [:]
    var onChanged: (() -> Void)?
    var color = Ink.purple
    var scale: CGFloat = 2
    var tool: DrawingTool = .pen
    var opacity: CGFloat = 1
    var smoothing: StrokeSmoothing = .light
    var keep: Bool { Preferences.fadeSeconds <= 0 }
    var isDrawing: Bool { draft != nil || editingMarker != nil }
    var canUndo: Bool { document.canUndo }
    var canRedo: Bool { document.canRedo }
    var count: Int { document.annotations.count }

    static let purple = CGColor(srgbRed: 0.53, green: 0.33, blue: 0.95, alpha: 1)
    static let red = CGColor(srgbRed: 1, green: 0.16, blue: 0.12, alpha: 1)
    static func hex(_ v: UInt32) -> CGColor {
        CGColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
                blue: CGFloat(v & 255) / 255, alpha: 1)
    }

    func begin(at point: CGPoint, width: CGFloat) {
        cancel()
        pressPoint = point
        let style = AnnotationStyle(color: AnnotationColor(color), width: width, opacity: opacity, smoothing: smoothing)
        if tool == .number, let marker = document.marker(at: point), case .number(_, let center) = marker.shape {
            editingMarker = marker
            markerOffset = CGPoint(x: center.x - point.x, y: center.y - point.y)
            changedMarker = false
            return
        }
        let shape: Annotation.Shape
        switch tool {
        case .pen: shape = .pen([point])
        case .rectangle: shape = .rectangle(point, point)
        case .arrow: shape = .arrow(point, point)
        case .number: shape = .number(document.nextNumber, point)
        case .text: return
        }
        draft = Annotation(shape: shape, style: style)
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
        case .rectangle(let a, _): annotation.shape = .rectangle(a, point)
        case .arrow(let a, _): annotation.shape = .arrow(a, point)
        case .number(let n, _): annotation.shape = .number(n, point)
        case .text: break
        }
        draft = annotation
        render()
    }

    func end() {
        var committed: UUID?
        if let marker = editingMarker {
            if changedMarker { document.replace(marker) } else { document.remove(marker.id) }
        } else if let annotation = draft, annotation.isMeaningful {
            document.append(annotation)
            committed = annotation.id
        }
        draft = nil
        editingMarker = nil
        pressPoint = nil
        render()
        if let id = committed, !keep, let visible = rendered[id]?.1 {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1
            animation.toValue = 0
            animation.beginTime = CACurrentMediaTime() + max(0.5, Preferences.fadeSeconds)
            animation.duration = 0.6
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            visible.add(animation, forKey: "fade")
        }
        onChanged?()
    }

    func addText(_ text: String, at point: CGPoint, width: CGFloat) {
        let style = AnnotationStyle(color: AnnotationColor(color), width: width, opacity: opacity, smoothing: smoothing)
        document.append(Annotation(shape: .text(text, point), style: style))
        render()
        onChanged?()
    }
    func cancel() {
        draft = nil
        editingMarker = nil
        pressPoint = nil
        render()
    }
    func undo() { cancel(); document.undo(); render(); onChanged?() }
    func redo() { cancel(); document.redo(); render(); onChanged?() }
    func clear() { cancel(); document.clear(); render(); onChanged?() }
    func reset() { cancel(); document.reset(); render(); onChanged?() }

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
        CATransaction.commit()
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
        let size = (text as NSString).size(withAttributes: [.font: font])
        label.string = text
        label.font = font
        label.fontSize = fontSize
        label.foregroundColor = color
        label.contentsScale = scale
        label.anchorPoint = .zero
        label.frame = CGRect(x: point.x, y: point.y - ceil(size.height), width: ceil(size.width) + 4, height: ceil(size.height) + 2)
        return label
    }
}
