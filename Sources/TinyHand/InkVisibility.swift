import Foundation
import CoreGraphics

/// Captured for each gesture, so changing preferences cannot resurrect expired ink.
struct InkLifetimePolicy {
    var style: InkFadeStyle
    var delay: TimeInterval
    var trailDelay: TimeInterval
    var trailSpeed: CGFloat
    static var current: Self {
        Self(style: Preferences.inkFadeStyle, delay: max(0.5, Preferences.fadeSeconds),
             trailDelay: Preferences.trailDelay, trailSpeed: CGFloat(Preferences.trailSpeed))
    }
}

/// Presentation lifetime never edits AnnotationDocument or its semantic history.
struct InkVisibility {
    struct State: Equatable {
        var opacity: CGFloat = 1
        var strokeStart: CGFloat = 0
        var visible: Bool { opacity > 0 && strokeStart < 1 }
    }
    private struct Lifetime {
        let policy: InkLifetimePolicy
        var committed: TimeInterval?
        var trail: InkTrail?
        var state = State()
    }
    private var entries: [UUID: Lifetime] = [:]
    var hasActiveTrails: Bool { entries.values.contains { $0.trail != nil && $0.state.visible } }
    var needsClock: Bool {
        entries.values.contains { $0.state.visible && ($0.trail != nil || ($0.committed != nil && $0.policy.style != .permanent)) }
    }
    func state(for id: UUID) -> State { entries[id]?.state ?? State() }

    mutating func begin(_ annotation: Annotation, at time: TimeInterval, policy: InkLifetimePolicy) {
        var lifetime = Lifetime(policy: policy)
        if policy.style == .trail, case .pen(let points) = annotation.shape, let first = points.first {
            var trail = InkTrail(at: first, time: time)
            for point in points.dropFirst() { trail.append(point, time: time) }
            lifetime.trail = trail
        }
        entries[annotation.id] = lifetime
    }
    mutating func append(_ point: CGPoint, to id: UUID, at time: TimeInterval) {
        guard var lifetime = entries[id], var trail = lifetime.trail else { return }
        trail.append(point, time: time)
        lifetime.trail = trail
        lifetime.state = State(strokeStart: trail.fraction)
        entries[id] = lifetime
    }
    mutating func finish(_ id: UUID, at time: TimeInterval) {
        entries[id]?.committed = time
        entries[id]?.trail?.finished = true
    }
    mutating func remove(_ id: UUID) { entries.removeValue(forKey: id) }

    /// Undo/Redo revives only newly restored or changed objects. Unchanged expired
    /// objects keep their old visibility. All restored paths retain their full geometry.
    mutating func reconcile(from before: [Annotation], to after: [Annotation], at time: TimeInterval, policy: InkLifetimePolicy) {
        let old = Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0) })
        let ids = Set(after.map(\.id))
        entries = entries.filter { ids.contains($0.key) }
        for annotation in after where old[annotation.id] != annotation {
            begin(annotation, at: time, policy: policy)
            finish(annotation.id, at: time)
        }
    }
    mutating func advance(to time: TimeInterval) {
        for id in Array(entries.keys) {
            guard var lifetime = entries[id], lifetime.state.visible else { continue }
            if var trail = lifetime.trail {
                trail.advance(to: time, delay: lifetime.policy.trailDelay, speed: lifetime.policy.trailSpeed)
                lifetime.trail = trail
                lifetime.state.strokeStart = trail.fraction
                if trail.complete { lifetime.state.opacity = 0 }
            } else if let start = lifetime.committed, lifetime.policy.style != .permanent {
                // Text, markers and non-freehand shapes fade as a whole in Trail too.
                lifetime.state.opacity = max(0, min(1, 1 - (time - start - lifetime.policy.delay) / 0.6))
            }
            entries[id] = lifetime
        }
    }
}
