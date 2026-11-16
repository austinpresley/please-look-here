import AppKit
import Combine

/// Value configuration for an independent practice document. No preference writes.
struct DrawingPracticeConfiguration: Equatable {
    var tool: DrawingTool
    var color: AnnotationColor
    var width: CGFloat
    var opacity: CGFloat
    var smoothing: StrokeSmoothing
    var fadeStyle: InkFadeStyle
    var fadeDelay: TimeInterval
    var trailDelay: TimeInterval
    var trailSpeed: CGFloat

    static var current: Self {
        let policy = InkLifetimePolicy.current
        return Self(tool: Preferences.drawingTool, color: AnnotationColor(Preferences.inkChoice.resolved(for: .saved)),
                    width: Preferences.strokeWidth, opacity: Preferences.inkOpacity, smoothing: Preferences.strokeSmoothing,
                    fadeStyle: policy.style, fadeDelay: policy.delay, trailDelay: policy.trailDelay, trailSpeed: policy.trailSpeed)
    }
    var lifetime: InkLifetimePolicy {
        InkLifetimePolicy(style: fadeStyle, delay: fadeDelay, trailDelay: trailDelay, trailSpeed: trailSpeed)
    }
    var lifetimeDescription: String {
        switch fadeStyle {
        case .permanent: return "Keep until cleared. The sample stays here."
        case .wholeLine: return String(format: "Whole line fades after %.1f seconds.", fadeDelay)
        case .trail: return String(format: "Trail starts after %.1f seconds at %.0f pt/s.", trailDelay, trailSpeed)
        }
    }
}

/// Owns only local ink. Reusable by Settings and a future practice window.
final class DrawingPracticeSession: ObservableObject {
    enum Mode: String, CaseIterable { case interact = "Interact", draw = "Draw" }
    private final class Policy { var value: InkLifetimePolicy; init(_ value: InkLifetimePolicy) { self.value = value } }
    let ink: Ink
    private let policy: Policy
    private(set) var configuration: DrawingPracticeConfiguration
    @Published var mode: Mode = .draw { didSet { ink.cancel() } }
    @Published var text = "Sample label"

    init(configuration: DrawingPracticeConfiguration, clock: @escaping () -> TimeInterval = { CACurrentMediaTime() }) {
        self.configuration = configuration
        let policy = Policy(configuration.lifetime)
        self.policy = policy
        ink = Ink(clock: clock, lifetimePolicy: { policy.value })
        applyStyle()
    }

    @discardableResult
    func configure(_ configuration: DrawingPracticeConfiguration) -> Bool {
        guard self.configuration != configuration else { return false }
        ink.cancel()
        self.configuration = configuration
        policy.value = configuration.lifetime
        applyStyle()
        return true
    }
    private func applyStyle() {
        ink.tool = configuration.tool; ink.color = configuration.color.cgColor(opacity: 1)
        ink.opacity = configuration.opacity; ink.smoothing = configuration.smoothing
    }
    func replay(in bounds: CGRect) {
        clear()
        guard bounds.width > 0, bounds.height > 0 else { return }
        // Use the same raw points at every smoothing level, including small corners.
        let sample: [CGPoint] = (0...48).map { index in
            let fraction = CGFloat(index) / 48
            return CGPoint(x: bounds.minX + bounds.width * (0.12 + 0.76 * fraction),
                           y: bounds.midY + sin(fraction * .pi * 4) * bounds.height * 0.20 + (index.isMultiple(of: 2) ? 3 : -3))
        }
        // The shared sample is always a freehand line; practice uses the selected tool.
        ink.tool = configuration.tool == .highlighter ? .highlighter : .pen
        ink.begin(at: sample[0], width: configuration.width)
        // Render immediately so repeated slider changes keep a complete sample
        // visible. InkVisibility supplies the real delay and trail progression.
        for point in sample.dropFirst() { ink.extend(to: point) }
        ink.end(); applyStyle()
    }
    func begin(at point: CGPoint) {
        guard mode == .draw else { return }
        cancel(); applyStyle()
        if configuration.tool == .text { ink.addText(text, at: point, width: configuration.width) }
        else { ink.begin(at: point, width: configuration.width) }
    }
    func extend(to point: CGPoint) { if mode == .draw { ink.extend(to: point) } }
    func end() { ink.end() }
    func cancel() { ink.cancel(); applyStyle() }
    func clear() { cancel(); ink.reset() }
    func undo() { cancel(); ink.undo() }
}
