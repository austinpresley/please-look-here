import AppKit
import Combine
import SwiftUI

final class GettingStartedPracticeWindow: NSObject, NSWindowDelegate {
    var openShortcut: ((PracticeShortcutTarget) -> Void)?
    var readiness: (() -> PracticeReadiness)?
    var onVisibilityChanged: (() -> Void)?
    var nativeWindow: NSWindow? { window }
    private var window: NSWindow?
    private var session: GettingStartedPracticeSession?

    func show(_ lesson: PracticeLesson = .pointer) {
        if window == nil {
            let session = GettingStartedPracticeSession(pointerConfiguration: .current)
            self.session = session
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 560, height: 560),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Getting Started Practice"
            window.minSize = CGSize(width: 560, height: 520)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: GettingStartedPracticeView(session: session,
                readiness: { [weak self] in self?.readiness?() ?? PracticeReadiness(drawingAllowed: false, radialAssigned: false, capturing: false) },
                openShortcut: { [weak self] in self?.openShortcut?($0) }, close: { [weak self] in self?.window?.performClose(nil) }))
            self.window = window
        }
        session?.select(lesson)
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible != true { window?.center() }
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(nil)
        onVisibilityChanged?()
    }
    /// Local exercise actions, called only by the disposable test-mode bridge.
    func verify(_ request: [String: Any]) -> [String: Any] {
        if request["completePrevious"] as? Bool == true, let session {
            session.select(.pointer); session.pointerOn = true; session.clickPracticeButton()
            session.select(.drawing)
        }
        if request["completeCurrent"] as? Bool == true, let session {
            if session.lesson == .drawing {
                session.drawing.begin(at: CGPoint(x: 40, y: 60)); session.drawing.extend(to: CGPoint(x: 220, y: 140)); session.drawing.end()
            } else if session.lesson == .radial {
                session.beginRadial(); session.moveRadialToTools(); session.moveRadialToPen(); session.releaseRadial()
            } else { session.pointerOn = true; session.interactOn = true; session.clickPracticeButton() }
        }
        return ["progress": session?.progressAnnouncement ?? "", "succeeded": session?.succeeded ?? false,
                "completed": session?.completedSteps.map(\.rawValue).sorted() ?? []]
    }
    func windowWillClose(_ notification: Notification) {
        session?.stop()
        // Destroy native preview views as well as their timers when closing.
        window?.contentView = nil
        window = nil
        session = nil
        onVisibilityChanged?()
    }
    func windowDidResignKey(_ notification: Notification) { session?.cancel(); onVisibilityChanged?() }
    func windowDidBecomeKey(_ notification: Notification) { onVisibilityChanged?() }
}

private struct GettingStartedPracticeView: View {
    @ObservedObject var session: GettingStartedPracticeSession
    let readiness: () -> PracticeReadiness
    let openShortcut: (PracticeShortcutTarget) -> Void
    let close: () -> Void
    @State private var desktopReadiness = PracticeReadiness(drawingAllowed: false, radialAssigned: false, capturing: false)
    private let readinessTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var accent: Color { Color(nsColor: ControlPalette.accent(NSApp.effectiveAppearance)) }
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    HStack(spacing: Space.md) {
                        ForEach(PracticeLesson.allCases, id: \.rawValue) { lesson in
                            ZStack(alignment: .bottomTrailing) {
                                PracticeStepGlyph(lesson: lesson)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(lesson == session.lesson ? accent.opacity(0.2) : Color.primary.opacity(0.06)))
                                    .overlay(Circle().strokeBorder(lesson == session.lesson ? accent : .clear, lineWidth: 2))
                                    .foregroundStyle(lesson == session.lesson ? accent : Color.secondary)
                                if session.completedSteps.contains(lesson) {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(accent)
                                        .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                                }
                            }.accessibilityElement(children: .ignore)
                                .accessibilityLabel(lesson.progressName)
                                .accessibilityValue(lesson == session.lesson ? "Current step" : session.completedSteps.contains(lesson) ? "Completed" : "Upcoming")
                                .accessibilityAddTraits(lesson == session.lesson ? .isSelected : [])
                        }
                        Spacer()
                        Text("\(session.lesson.rawValue + 1) of 4").font(.system(size: 12)).monospacedDigit()
                    }.accessibilityElement(children: .contain).accessibilityLabel(session.progressAnnouncement)
                    HStack(spacing: Space.sm) {
                        Text(session.lesson.title).font(.title3).bold()
                        Spacer()
                        Image(systemName: "info.circle").foregroundStyle(.secondary)
                            .help(desktopReadiness.message(for: session.lesson))
                            .accessibilityLabel(desktopReadiness.message(for: session.lesson))
                        Button { openShortcut(session.lesson.shortcutTarget) } label: { Image(systemName: "keyboard") }
                            .help("Open \(session.lesson.shortcutTarget.title) in Shortcuts")
                            .accessibilityLabel("Open \(session.lesson.shortcutTarget.title) in Shortcuts")
                    }
                    if session.lesson != .drawing { Text(session.lesson.instruction).fixedSize(horizontal: false, vertical: true) }
                    lessonContent
                        .gridProbe("practice.lesson", area: "practice")
                    if session.succeeded { Label("You did it", systemImage: "checkmark.circle.fill").foregroundStyle(accent) }


                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.margin)
                .gridArea("practice", inset: Space.margin)
            }
            Divider()
            HStack(spacing: Space.sm) {
                Button { if let lesson = PracticeLesson(rawValue: session.lesson.rawValue - 1) { session.select(lesson) } } label: { Image(systemName: "chevron.left") }
                    .disabled(session.lesson == .pointer).help("Back to the previous step").accessibilityLabel("Back")
                Button { session.replayStep() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Replay this practice step").accessibilityLabel("Replay Step")
                if session.lesson == .radial { Button("Start Again") { session.replayAll() } }
                Spacer(minLength: Space.sm)
                Button("Skip") { advance() }
                Button(session.lesson == .radial ? "Done" : "Next") {
                    advance()
                }.keyboardShortcut(.defaultAction).disabled(!session.succeeded)
            }.padding([.horizontal, .bottom], Space.margin)
        }
        .tint(Color(nsColor: ControlPalette.accent(NSApp.effectiveAppearance)))
        .onAppear { desktopReadiness = readiness() }
        .onReceive(readinessTimer) { _ in desktopReadiness = readiness() }
        .onExitCommand { session.cancel() }
    }
    private func advance() {
        if let lesson = PracticeLesson(rawValue: session.lesson.rawValue + 1) { session.select(lesson) }
        else { close() }
    }
    @ViewBuilder private var lessonContent: some View {
        switch session.lesson {
        case .pointer, .interact, .drawing:
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(spacing: Space.sm) {
                    Button { session.pointerOn = true; session.interactOn = true } label: { Image(systemName: "cursorarrow") }
                        .help("Cursor: use the sample app").accessibilityLabel("Cursor")
                    Button { session.pointerOn = true; session.interactOn = false } label: { Image(systemName: "pencil.tip") }
                        .help("Pen: draw locally").accessibilityLabel("Pen")
                    Text(session.interactOn ? "Cursor" : "Pen").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    if !session.pointerOn { Button("Show sample pointer") { session.pointerOn = true } }
                    Button { session.drawing.undo() } label: { Image(systemName: "arrow.uturn.backward") }.help("Undo practice drawing").accessibilityLabel("Undo").disabled(session.annotationCount == 0)
                    Button { session.drawing.clear() } label: { Image(systemName: "trash") }.help("Clear practice drawing").accessibilityLabel("Clear").disabled(session.annotationCount == 0)
                }
                if session.lesson != .drawing {
                    Button("Click me") { session.clickPracticeButton() }
                        .disabled(!session.pointerOn || !session.interactOn)
                        .frame(maxWidth: .infinity, minHeight: 48)
                    Text("Clicks received: \(session.clicks)").font(.callout)
                }
                PracticeInkCanvas(session: session.drawing, configuration: session.drawingConfiguration)
                    .frame(height: session.lesson == .drawing ? 300 : 200)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: Space.sm).strokeBorder(Color.primary.opacity(0.16)))

            }
        case .radial:
            VStack(alignment: .leading, spacing: Space.md) {
                Text(Preferences.radialTrigger.map { "On your desktop: \($0.holdHelp)" } ?? "On your desktop: set a held key in Shortcuts. Hold the center to practice here.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack(spacing: Space.md) {
                    Label("Hold center", systemImage: "hand.point.up.left")
                    Image(systemName: "arrow.right")
                    Label("Move", systemImage: "cursorarrow.motionlines")
                    Image(systemName: "arrow.right")
                    Label("Release", systemImage: "hand.raised")
                }.font(.callout)
                LocalRadialPracticeCanvas(session: session).frame(height: 240)
                Text("Esc or center: cancel").font(.callout).foregroundStyle(.secondary)
                Text(session.radialFeedback).font(.callout).fixedSize(horizontal: false, vertical: true)
                // Native buttons provide the same hold/move/release path with a keyboard or VoiceOver.
                HStack(spacing: Space.sm) {
                    Button("Hold Quick controls") { session.beginRadial() }.disabled(session.radial != nil)
                    Button("Move to Draw") { session.moveRadialToTools() }.disabled(session.radial == nil)
                    Button("Move to Pen") { session.moveRadialToPen() }.disabled(session.radial?.group == nil)
                    Button("Release") { session.releaseRadial() }.disabled(session.radial == nil)
                    Button("Cancel") { session.cancelRadial() }.disabled(session.radial == nil)
                }
            }
        }
    }
}

private struct PracticeInkCanvas: NSViewRepresentable {
    let session: DrawingPracticeSession
    let configuration: DrawingPracticeConfiguration
    func makeNSView(context: Context) -> GettingStartedInkView { GettingStartedInkView(session: session) }
    func updateNSView(_ view: GettingStartedInkView, context: Context) { session.configure(configuration) }
    static func dismantleNSView(_ view: GettingStartedInkView, coordinator: ()) { view.session.cancel() }
}

/// Unlike the Settings preview, onboarding never inserts sample ink on mount,
/// replay or resize. Only a completed local gesture can satisfy the lesson.
final class GettingStartedInkView: NSView {
    let session: DrawingPracticeSession
    init(session: DrawingPracticeSession) {
        self.session = session; super.init(frame: .zero)
        wantsLayer = true; layer?.masksToBounds = true; layer?.addSublayer(session.ink.layer)
        setAccessibilityElement(true); setAccessibilityRole(.image)
        setAccessibilityLabel("Practice canvas")
        setAccessibilityHelp("Choose Pen and drag a line here. Cursor leaves the ink unchanged.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    override var acceptsFirstResponder: Bool { true }
    override func layout() { super.layout(); session.ink.scale = window?.backingScaleFactor ?? 2 }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); session.begin(at: convert(event.locationInWindow, from: nil)) }
    override func mouseDragged(with event: NSEvent) { session.extend(to: convert(event.locationInWindow, from: nil)) }
    override func mouseUp(with event: NSEvent) { session.end() }
    override func cancelOperation(_ sender: Any?) { session.cancel() }
}

private struct LocalRadialPracticeCanvas: NSViewRepresentable {
    @ObservedObject var session: GettingStartedPracticeSession
    func makeNSView(context: Context) -> LocalRadialPracticeView { LocalRadialPracticeView(session: session) }
    func updateNSView(_ view: LocalRadialPracticeView, context: Context) { view.needsDisplay = true }
    static func dismantleNSView(_ view: LocalRadialPracticeView, coordinator: ()) { view.session.cancelRadial() }
}

/// Native window-local presses only. No event monitor, modifier, tap or app command.
private final class LocalRadialPracticeView: NSView {
    let session: GettingStartedPracticeSession
    init(session: GettingStartedPracticeSession) {
        self.session = session
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Local radial practice")
        setAccessibilityHelp("Hold the center, drag right through Draw, then move to Pen and release. Keyboard users can use the Hold Quick controls, Move and Release buttons below.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    override var acceptsFirstResponder: Bool { true }
    private var scale: CGFloat { min(bounds.width, bounds.height) / RadialGeometry.size }
    private func displayPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: bounds.midX + (point.x - 296) * scale, y: bounds.midY + (point.y - 296) * scale)
    }
    private func lessonPoint(_ event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        return CGPoint(x: 296 + (point.x - bounds.midX) / max(scale, 0.01), y: 296 + (point.y - bounds.midY) / max(scale, 0.01))
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill(); NSBezierPath(rect: bounds).fill()
        let radial = session.radial ?? GettingStartedPracticeSession.radialTemplate
        let center = displayPoint(radial.geometry.center)
        NSColor.separatorColor.setStroke()
        let ring = NSBezierPath(ovalIn: CGRect(x: center.x - 164 * scale, y: center.y - 164 * scale, width: 328 * scale, height: 328 * scale))
        ring.stroke()
        for (slot, item) in radial.items.enumerated() where item.enabled {
            let point = displayPoint(RadialGeometry.point(angle: radial.angle(for: slot), radius: RadialGeometry.rootRadius, center: radial.geometry.center))
            let width: CGFloat = radial.group == nil ? 56 : 72
            let rect = CGRect(x: point.x - width / 2, y: point.y - 16, width: width, height: 32)
            (radial.highlighted == slot ? NSColor.selectedControlColor : NSColor.controlBackgroundColor).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
            drawLabel(item.title, in: rect, selected: radial.highlighted == slot)
        }
        drawLabel(session.radial == nil ? "Hold" : "Cancel", in: CGRect(x: center.x - 24, y: center.y - 16, width: 48, height: 32))
        if session.radial != nil && radial.geometry.distance(radial.point) > RadialGeometry.centerRadius {
            let point = displayPoint(radial.point)
            NSColor.labelColor.setFill(); NSBezierPath(ovalIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)).fill()
        }
    }
    private func drawLabel(_ title: String, in rect: CGRect, selected: Bool = false) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        (title as NSString).draw(in: rect.insetBy(dx: 0, dy: 8), withAttributes: [.font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: selected ? NSColor.selectedControlTextColor : NSColor.labelColor, .paragraphStyle: paragraph])
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = lessonPoint(event)
        if GettingStartedPracticeSession.radialTemplate.geometry.distance(point) <= RadialGeometry.centerRadius { session.beginRadial() }
    }
    override func mouseDragged(with event: NSEvent) { session.moveRadial(to: lessonPoint(event)) }
    override func mouseUp(with event: NSEvent) { session.moveRadial(to: lessonPoint(event)); session.releaseRadial() }
    override func cancelOperation(_ sender: Any?) { session.cancelRadial() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if window == nil { session.cancelRadial() } }
}
