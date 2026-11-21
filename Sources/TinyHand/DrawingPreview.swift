import AppKit
import SwiftUI

struct DrawingPreview: View {
    let configuration: DrawingPracticeConfiguration
    @StateObject private var session: DrawingPracticeSession
    @State private var replay = 0
    @State private var practiceTool: DrawingTool = .pen
    @State private var darkBackground: Bool?
    @Environment(\.colorScheme) private var colorScheme
    private var usesDarkBackground: Bool { darkBackground ?? (colorScheme == .dark) }

    private var sampleConfiguration: DrawingPracticeConfiguration {
        var value = configuration; value.tool = practiceTool; return value
    }
    init(configuration: DrawingPracticeConfiguration) {
        self.configuration = configuration
        _session = StateObject(wrappedValue: DrawingPracticeSession(configuration: configuration))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Picker("Practice tool", selection: $practiceTool) {
                    Label("Pen", systemImage: "pencil.tip").tag(DrawingTool.pen)
                    Label("Arrow", systemImage: "arrow.up.right").tag(DrawingTool.arrow)
                }.labelsHidden().pickerStyle(.segmented).frame(width: 144)
                Spacer(minLength: Space.sm)
                practiceButton("Undo", symbol: "arrow.uturn.backward", enabled: session.ink.canUndo) { session.undo() }
                practiceButton("Replay sample", symbol: "arrow.clockwise") { replay += 1 }
                Toggle(isOn: Binding(get: { usesDarkBackground }, set: { darkBackground = $0 })) { Image(systemName: usesDarkBackground ? "moon.fill" : "moon") }
                    .toggleStyle(.button).help("Use a dark practice background").accessibilityLabel("Dark practice background")
                practiceButton("Clear practice canvas", symbol: "trash", enabled: session.ink.canUndo || session.ink.isDrawing) { session.clear() }
            }.gridProbe("drawingPreview.controls", area: "drawingPreview")
            DrawingPracticeCanvas(session: session, configuration: sampleConfiguration, replay: replay)
                .frame(height: 128)
                // These are sample paper colors, independent of the app's theme.
                .background(usesDarkBackground ? Color(white: 0.10) : .white)
                .clipShape(RoundedRectangle(cornerRadius: Space.sm))
                .overlay(RoundedRectangle(cornerRadius: Space.sm).strokeBorder(Color.primary.opacity(0.16)))
                .gridProbe("drawingPreview.canvas", area: "drawingPreview")
            Text(configuration.lifetimeDescription)
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .gridProbe("drawingPreview.lifetime", area: "drawingPreview")
        }
        .padding(Space.md)
        .background(RoundedRectangle(cornerRadius: Space.md).fill(Color.primary.opacity(0.045)))
        .gridArea("drawingPreview", inset: Space.md)
        .onExitCommand { session.cancel() }
    }
    private func practiceButton(_ title: String, symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .disabled(!enabled).help(title).accessibilityLabel(title)
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
