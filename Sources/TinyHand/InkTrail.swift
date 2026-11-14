import Foundation
import CoreGraphics

enum InkFadeStyle: String, CaseIterable {
    case wholeLine, trail, permanent
    var title: String {
        switch self {
        case .wholeLine: return "Whole line"
        case .trail: return "Trail"
        case .permanent: return "Keep until cleared"
        }
    }
}

/// Time-stamped distance protects the newest ink while the eraser catches up.
/// The document keeps complete points; this model changes only their visibility.
struct InkTrail {
    private struct Sample { let time: TimeInterval; let distance: CGFloat }
    private var samples: [Sample]
    private var lastPoint: CGPoint
    private var lastStep: TimeInterval
    private(set) var length: CGFloat = 0
    private(set) var erased: CGFloat = 0
    var finished = false
    var fraction: CGFloat { length > 0 ? min(1, erased / length) : 0 }
    var complete: Bool { finished && (length == 0 || erased >= length) }

    init(at point: CGPoint, time: TimeInterval) {
        lastPoint = point; lastStep = time
        samples = [Sample(time: time, distance: 0)]
    }
    mutating func append(_ point: CGPoint, time: TimeInterval) {
        length += hypot(point.x - lastPoint.x, point.y - lastPoint.y)
        lastPoint = point
        samples.append(Sample(time: time, distance: length))
    }
    mutating func advance(to time: TimeInterval, delay: TimeInterval, speed: CGFloat) {
        let elapsed = max(0, time - max(lastStep, (samples.first?.time ?? time) + delay))
        lastStep = max(lastStep, time)
        let cutoff = time - delay
        var limit: CGFloat = 0
        if let index = samples.lastIndex(where: { $0.time <= cutoff }) {
            let sample = samples[index]
            limit = sample.distance
            if index + 1 < samples.count {
                let next = samples[index + 1], duration = next.time - sample.time
                if duration > 0 { limit += (next.distance - sample.distance) * min(1, CGFloat((cutoff - sample.time) / duration)) }
            }
        }
        erased = min(max(erased, limit), erased + max(0, speed) * elapsed)
    }
}
