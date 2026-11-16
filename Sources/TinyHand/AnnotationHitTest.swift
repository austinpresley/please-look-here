import AppKit

/// Tests the rendered shape, including only the remaining portion of a trail.
/// Object selection follows document paint order and never mutates geometry.
enum AnnotationHitTest {
    static func topmost(at point: CGPoint, in annotations: [Annotation], visibility: (UUID) -> InkVisibility.State) -> Annotation? {
        annotations.reversed().first { annotation in
            let state = visibility(annotation.id)
            return state.visible && contains(point, annotation: annotation, strokeStart: state.strokeStart)
        }
    }

    static func contains(_ point: CGPoint, annotation: Annotation, strokeStart: CGFloat = 0) -> Bool {
        guard strokeStart < 1, annotation.style.opacity > 0 else { return false }
        switch annotation.shape {
        case .text(let text, let anchor):
            return AnnotationGeometry.textBounds(text, at: anchor, fontSize: max(16, annotation.style.width * 3)).insetBy(dx: -4, dy: -4).contains(point)
        case .number(_, let center):
            return hypot(point.x - center.x, point.y - center.y) <= annotation.markerRadius + 4
        default:
            let path = AnnotationGeometry.path(annotation)
            let visible = strokeStart > 0 ? suffix(of: path, fraction: strokeStart) : path
            return visible.copy(strokingWithWidth: annotation.style.width + 8, lineCap: .round, lineJoin: .round, miterLimit: 10).contains(point)
        }
    }

    /// Core Animation trims by path length. Flatten only for a partial trail hit,
    /// sampling its quadratic pen curves without changing the semantic path.
    private static func suffix(of path: CGPath, fraction: CGFloat) -> CGPath {
        var points: [CGPoint] = []
        var cursor = CGPoint.zero
        path.applyWithBlock { pointer in
            let element = pointer.pointee
            switch element.type {
            case .moveToPoint, .addLineToPoint:
                cursor = element.points[0]; points.append(cursor)
            case .addQuadCurveToPoint:
                let start = cursor, control = element.points[0], end = element.points[1]
                for step in 1...16 {
                    let t = CGFloat(step) / 16, u = 1 - t
                    points.append(CGPoint(x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                                          y: u * u * start.y + 2 * u * t * control.y + t * t * end.y))
                }
                cursor = end
            default: break // Pen geometry contains only moves, lines and quadratic curves.
            }
        }
        let lengths = zip(points, points.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        let cutoff = lengths.reduce(0, +) * fraction
        var distance: CGFloat = 0
        let result = CGMutablePath()
        var started = false
        for (index, length) in lengths.enumerated() {
            let start = points[index], end = points[index + 1]
            if distance + length > cutoff {
                if !started {
                    let t = length > 0 ? max(0, (cutoff - distance) / length) : 0
                    result.move(to: CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t))
                    started = true
                }
                result.addLine(to: end)
            }
            distance += length
        }
        return result
    }
}
