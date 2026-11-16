import AppKit

/// Transient renderer inputs, never a saved override or inheritance model.
struct PointerPreviewConfiguration: Equatable {
    var style: PointerStyle
    var size: CGFloat
    var shadow: Bool
    var shadowStyle: PointerShadowStyle
    var motion: PointerMotion
    var tapSwing: Double

    /// Read-only Settings adapter, sharing the live renderer's inheritance policy.
    static var current: Self {
        let style = PointerStyle.saved
        let effective = Preferences.pointerConfiguration(for: style.rawValue)
        return Self(style: style, size: CGFloat(effective.size), shadow: effective.shadow,
                    shadowStyle: effective.shadowStyle, motion: Preferences.pointerMotion, tapSwing: Preferences.tapSwing)
    }
}

/// Local playback has no event posting, overlay activation, audio or preference writes.
struct PointerPreviewPlayback {
    private var motionStart: TimeInterval?
    private var tapStart: TimeInterval?
    private(set) var cursor = CGPoint.zero
    private(set) var held = false
    var playing: Bool { motionStart != nil || tapStart != nil }

    mutating func move(to point: CGPoint) { motionStart = nil; cursor = point }
    mutating func previewMotion(at time: TimeInterval) { motionStart = time }
    mutating func previewTap(at time: TimeInterval) { tapStart = time; held = true }
    mutating func cancel() { motionStart = nil; tapStart = nil; held = false }
    mutating func advance(at time: TimeInterval, bounds: CGRect, reduceMotion: Bool) {
        if let start = tapStart, time - start >= 0.32 { held = false; tapStart = nil }
        guard let start = motionStart else { return }
        guard !reduceMotion else { motionStart = nil; cursor = CGPoint(x: bounds.midX, y: bounds.midY); return }
        let progress = min(1, max(0, (time - start) / 2))
        cursor = CGPoint(x: bounds.minX + bounds.width * (0.5 + 0.28 * sin(progress * 2 * .pi)),
                         y: bounds.minY + bounds.height * (0.60 + 0.14 * sin(progress * 4 * .pi)))
        if progress >= 1 { motionStart = nil }
    }
}
