import AppKit
import SwiftUI

struct DrawingPreview: View {
    let configuration: DrawingPracticeConfiguration
    @StateObject private var session: DrawingPracticeSession
    @State private var replay = 0
    init(configuration: DrawingPracticeConfiguration) {
        self.configuration = configuration
        _session = StateObject(wrappedValue: DrawingPracticeSession(configuration: configuration))
    }
    var body: some View {
        Card(title: "Practice drawing") {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(spacing: Space.sm) {
                    Picker("Practice mode", selection: $session.mode) {
                        ForEach(DrawingPracticeSession.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).frame(width: 172)
                    Spacer(minLength: Space.sm)
                    Button("Replay Sample") { replay += 1 }
                    Button("Undo") { session.undo() }.help("Undo the last practice annotation")
                    Button("Clear") { session.clear() }.help("Clear only this practice canvas")
                }
                .gridProbe("drawingPreview.controls", area: "drawingPreview")
                DrawingPracticeCanvas(session: session, configuration: configuration, replay: replay)
                    .frame(height: 148)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: Space.sm))
                    .overlay(RoundedRectangle(cornerRadius: Space.sm).strokeBorder(Color.primary.opacity(0.16)))
                    .gridProbe("drawingPreview.canvas", area: "drawingPreview")
                if configuration.tool == .text {
                    TextField("Practice text", text: $session.text)
                        .textFieldStyle(.roundedBorder)
                        .gridProbe("drawingPreview.text", area: "drawingPreview")
                }
                Text(configuration.lifetimeDescription)
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .gridProbe("drawingPreview.lifetime", area: "drawingPreview")
                Text(session.mode == .draw ? "Try \(configuration.tool.title.lowercased()) here. This canvas stays in Settings." : "Interact passes over the canvas without drawing. Choose Draw to practice.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .gridProbe("drawingPreview.help", area: "drawingPreview")
            }
            .padding(Space.lg)
            .gridArea("drawingPreview", inset: Space.lg)
        }
        .onExitCommand { session.cancel() }
    }
}

/// Host this with a caller-owned session and values; it has no overlay or input-tap dependencies.
struct DrawingPracticeCanvas: NSViewRepresentable {
    let session: DrawingPracticeSession
    let configuration: DrawingPracticeConfiguration
    var replay = 0
    func makeNSView(context: Context) -> DrawingPracticeView { DrawingPracticeView(session: session) }
    func updateNSView(_ view: DrawingPracticeView, context: Context) {
        let changed = session.configure(configuration)
        if changed || view.replay != replay {
            view.replay = replay
            view.replaySample()
        }
    }
    static func dismantleNSView(_ view: DrawingPracticeView, coordinator: ()) { view.stop() }
}

final class DrawingPracticeView: NSView {
    let session: DrawingPracticeSession
    var replay = 0
    private var lastSize = CGSize.zero
    init(session: DrawingPracticeSession) {
        self.session = session
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.addSublayer(session.ink.layer)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Local drawing practice canvas")
        setAccessibilityHelp("Drag to draw here. Use Replay Sample to preview settings without drawing.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    override var acceptsFirstResponder: Bool { true }
    override func layout() {
        super.layout()
        session.ink.scale = window?.backingScaleFactor ?? 2
        if bounds.size != lastSize { lastSize = bounds.size; replaySample() }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stop() } else { replaySample() }
    }
    func replaySample() {
        guard window != nil else { return }
        session.replay(in: bounds)
    }
    func stop() { session.clear() }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        session.begin(at: localPoint(event))
    }
    override func mouseDragged(with event: NSEvent) { session.extend(to: localPoint(event)) }
    override func mouseUp(with event: NSEvent) { session.end() }
    override func cancelOperation(_ sender: Any?) { session.cancel() }
    private func localPoint(_ event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        return CGPoint(x: min(bounds.maxX, max(bounds.minX, point.x)), y: min(bounds.maxY, max(bounds.minY, point.y)))
    }
}
