import AppKit
import SwiftUI

private enum PointerPreviewBackground: String, CaseIterable {
    case light = "Light", dark = "Dark", patterned = "Patterned"
}

struct PointerPreview: View {
    let configuration: PointerPreviewConfiguration
    @State private var background: PointerPreviewBackground = .light
    @State private var tap = 0
    @State private var motion = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Card(title: "Pointer preview") {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(spacing: Space.sm) {
                    Picker("Sample background", selection: $background) {
                        ForEach(PointerPreviewBackground.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented).frame(width: 232)
                    Spacer(minLength: Space.sm)
                    Button("Preview Tap") { tap += 1 }
                    Button("Preview Motion") { motion += 1 }.disabled(reduceMotion)
                }
                .fixedSize(horizontal: false, vertical: true)
                .gridProbe("pointerPreview.controls", area: "pointerPreview")
                PointerPreviewCanvas(configuration: configuration, tap: tap, motion: motion)
                    .frame(height: 180)
                    .background(sampleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Space.sm))
                    .overlay(RoundedRectangle(cornerRadius: Space.sm).strokeBorder(Color.primary.opacity(0.16)))
                    .gridProbe("pointerPreview.canvas", area: "pointerPreview")
                Text("\(configuration.style.title). Move over the sample or preview a tap. Your desktop pointer stays as it is.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .gridProbe("pointerPreview.help", area: "pointerPreview")
            }
            .padding(Space.lg)
            .gridArea("pointerPreview", inset: Space.lg)
        }
    }
    private var sampleBackground: some View {
        Canvas { context, size in
            let base: Color = background == .dark ? Color(white: 0.12) : Color(white: 0.96)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            if background == .patterned {
                for row in 0..<Int(ceil(size.height / 24)) {
                    for column in 0..<Int(ceil(size.width / 24)) where (row + column).isMultiple(of: 2) {
                        let square = CGRect(x: column * 24, y: row * 24, width: 24, height: 24)
                        context.fill(Path(square), with: .color(Color(white: 0.64)))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PointerPreviewCanvas: NSViewRepresentable {
    let configuration: PointerPreviewConfiguration
    let tap: Int
    let motion: Int
    func makeNSView(context: Context) -> PointerPreviewView { PointerPreviewView(configuration: configuration) }
    func updateNSView(_ view: PointerPreviewView, context: Context) {
        view.configure(configuration, tap: tap, motion: motion)
    }
    static func dismantleNSView(_ view: PointerPreviewView, coordinator: ()) { view.stop() }
}

final class PointerPreviewView: NSView {
    let arm: ArmView
    private(set) var playback = PointerPreviewPlayback()
    private var configuration: PointerPreviewConfiguration
    private var timer: Timer?
    private var tracking: NSTrackingArea?
    private var tap = 0
    private var motion = 0
    init(configuration: PointerPreviewConfiguration) {
        self.configuration = configuration
        arm = ArmView(frame: .zero, previewConfiguration: configuration)
        super.init(frame: .zero)
        wantsLayer = true; layer?.masksToBounds = true
        addSubview(arm)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Local preview of \(configuration.style.title)")
        setAccessibilityHelp("Use Preview Tap or Preview Motion to see the current pointer here.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    override var acceptsFirstResponder: Bool { true }
    // The renderer draws only; this host owns local pointer tracking and presses.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }
    override func layout() {
        super.layout(); arm.frame = bounds
        playback.move(to: CGPoint(x: bounds.midX, y: bounds.height * 0.6))
        arm.aim(cursor: playback.cursor)
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
    }
    func configure(_ value: PointerPreviewConfiguration, tap: Int, motion: Int) {
        if value != configuration {
            configuration = value; arm.applyPreviewConfiguration(value)
            setAccessibilityLabel("Local preview of \(value.style.title)")
            arm.aim(cursor: playback.cursor)
            wake()
        }
        if self.tap != tap { self.tap = tap; previewTap() }
        if self.motion != motion { self.motion = motion; playback.previewMotion(at: CACurrentMediaTime()); wake() }
    }
    private func previewTap() {
        playback.previewTap(at: CACurrentMediaTime()); arm.held = true; arm.press(); wake()
    }
    private func wake() {
        guard window != nil, timer == nil else { return }
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    private func step() {
        playback.advance(at: CACurrentMediaTime(), bounds: bounds, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        arm.held = playback.held; arm.aim(cursor: playback.cursor)
        if !playback.playing && !arm.isSettling { timer?.invalidate(); timer = nil }
    }
    func stop() { timer?.invalidate(); timer = nil; playback.cancel(); arm.held = false; arm.cancelTapAnimation() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if window == nil { stop() } }
    override func mouseMoved(with event: NSEvent) { playback.move(to: convert(event.locationInWindow, from: nil)); wake() }
    override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); mouseMoved(with: event); previewTap() }
    override func mouseUp(with event: NSEvent) { playback.cancel(); arm.held = false; wake() }
    override func mouseExited(with event: NSEvent) { playback.cancel(); arm.held = false; wake() }
    override func cancelOperation(_ sender: Any?) { stop() }
}
