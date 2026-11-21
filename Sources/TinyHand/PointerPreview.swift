import AppKit
import SwiftUI

private enum PointerPreviewBackground: String, CaseIterable {
    case light = "Light", dark = "Dark", patterned = "Patterned"
    var symbol: String { switch self { case .light: return "sun.max"; case .dark: return "moon"; case .patterned: return "square.grid.3x3" } }
}

struct PointerPreview: View {
    let configuration: PointerPreviewConfiguration
    var compact = false
    var inspector = false
    @State private var background: PointerPreviewBackground = .light
    @State private var tap = 0
    @State private var motion = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Card(title: inspector ? nil : "Pointer preview") {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(spacing: Space.sm) {
                    Picker("Sample background", selection: $background) {
                        ForEach(PointerPreviewBackground.allCases, id: \.self) { background in
                            if inspector { Image(systemName: background.symbol).tag(background).help(background.rawValue).accessibilityLabel(background.rawValue) }
                            else { Text(background.rawValue).tag(background) }
                        }
                    }.labelsHidden().pickerStyle(.segmented).frame(width: inspector ? 176 : 232)
                    Spacer(minLength: Space.sm)
                    Menu {
                        Button("Preview Tap") { tap += 1 }
                        Button("Preview Motion") { motion += 1 }.disabled(reduceMotion)
                    } label: { Image(systemName: "play.fill") }
                        .menuStyle(.borderlessButton).fixedSize()
                        .accessibilityLabel("Preview Tap or Motion").help("Preview a tap or pointer motion in this sample")
                }
                .fixedSize(horizontal: false, vertical: true)
                .gridProbe("pointerPreview.controls", area: "pointerPreview")
                Group {
                    if inspector, let name = configuration.style.assetName, !HandAsset.isAvailable(name) {
                        VStack(spacing: Space.sm) {
                            Image(systemName: "photo.badge.exclamationmark")
                            Text("Artwork unavailable").font(.callout)
                        }.foregroundStyle(background == .dark ? Color.white : Color.black)
                            .frame(maxWidth: .infinity).accessibilityLabel("Artwork unavailable for \(configuration.style.title)")
                    } else { PointerPreviewCanvas(configuration: configuration, tap: tap, motion: motion) }
                }
                    .frame(height: inspector ? 96 : compact ? 112 : 180)
                    .background(sampleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Space.sm))
                    .overlay(RoundedRectangle(cornerRadius: Space.sm).strokeBorder(Color.primary.opacity(0.16)))
                    .gridProbe("pointerPreview.canvas", area: "pointerPreview")
                if inspector && compact { Text("Sample").font(.system(size: 10)).foregroundStyle(.secondary) }
                if !inspector {
                Text(compact ? "This sample uses Pointer defaults. Customized pointers keep their own values." : "\(configuration.style.title). Move over the sample or preview a tap. Your desktop pointer stays as it is.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .gridProbe("pointerPreview.help", area: "pointerPreview")
                }
                if hasCustomizedAppearance && !compact && !inspector {
                    Text("Some appearance values are customized for \(configuration.style.title) in Pointers.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .gridProbe("pointerPreview.customization", area: "pointerPreview")
                }
            }
            .padding(inspector ? Space.sm : Space.lg)
            .gridArea("pointerPreview", inset: inspector ? Space.sm : Space.lg)
        }
    }
    private var hasCustomizedAppearance: Bool {
        guard let document = try? PointerConfigurationDocument.load(from: Preferences.storage),
              let customized = document.pointers[configuration.style.rawValue] else { return false }
        return customized.size != nil || customized.shadow != nil || customized.shadowStyle != nil
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
    private var lastSize = CGSize.zero
    init(configuration: PointerPreviewConfiguration) {
        self.configuration = configuration
        arm = ArmView(frame: .zero, previewConfiguration: configuration)
        super.init(frame: .zero)
        wantsLayer = true; layer?.masksToBounds = true
        arm.autoresizingMask = [.width, .height]
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
        super.layout()
        layoutRenderer()
    }
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutRenderer()
    }
    private func layoutRenderer() {
        arm.frame = bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        if lastSize != bounds.size {
            lastSize = bounds.size
            playback.move(to: CGPoint(x: bounds.midX, y: bounds.height * (configuration.referenceHeight == nil ? 0.6 : 0.72)))
        }
        arm.aim(cursor: playback.cursor)
        wake()
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
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stop() } else { layoutRenderer() }
    }
    override func mouseMoved(with event: NSEvent) { playback.move(to: convert(event.locationInWindow, from: nil)); wake() }
    override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); mouseMoved(with: event); previewTap() }
    override func mouseUp(with event: NSEvent) { playback.cancel(); arm.held = false; wake() }
    override func mouseExited(with event: NSEvent) { playback.cancel(); arm.held = false; wake() }
    override func cancelOperation(_ sender: Any?) { stop() }
}
