import AppKit
import Combine
import SwiftUI

final class GettingStartedPracticeWindow: NSObject, NSWindowDelegate {
    var openShortcut: ((PracticeShortcutTarget) -> Void)?
    var readiness: (() -> PracticeReadiness)?
    var onVisibilityChanged: (() -> Void)?
    private var window: NSWindow?
    private var session: GettingStartedPracticeSession?

    func show(_ lesson: PracticeLesson = .pointer) {
        if window == nil {
            let session = GettingStartedPracticeSession(pointerConfiguration: .current)
            self.session = session
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 560, height: 600),
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
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("Step \(session.lesson.rawValue + 1) of \(PracticeLesson.allCases.count)").font(.callout).foregroundStyle(.secondary)
                    Text(session.lesson.title).font(.title2).bold()
                    Text(session.lesson.instruction).fixedSize(horizontal: false, vertical: true)
                    Text("Practice stays in this window. No permission or shortcut is needed.").font(.callout).foregroundStyle(.secondary)
                    lessonContent
                        .gridProbe("practice.lesson", area: "practice")
                    Text(desktopReadiness.message(for: session.lesson)).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .gridProbe("practice.readiness", area: "practice")
                    Button("Open \(session.lesson.shortcutTarget.title) in Shortcuts…") { openShortcut(session.lesson.shortcutTarget) }
                        .help("Focus this command in Shortcuts. Recording starts only when you click its shortcut control.")
                    Text("Shortcuts stay unassigned until you choose them.").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.margin)
                .gridArea("practice", inset: Space.margin)
            }
            Divider()
            HStack(spacing: Space.sm) {
                Button("Back") { if let lesson = PracticeLesson(rawValue: session.lesson.rawValue - 1) { session.select(lesson) } }
                    .disabled(session.lesson == .pointer)
                Button("Replay Step") { session.replayStep() }
                if session.lesson == .radial { Button("Start Again") { session.replayAll() } }
                Spacer(minLength: Space.sm)
                Button(session.lesson == .radial ? "Done" : "Next") {
                    if let lesson = PracticeLesson(rawValue: session.lesson.rawValue + 1) { session.select(lesson) }
                    else { close() }
                }.keyboardShortcut(.defaultAction)
            }.padding([.horizontal, .bottom], Space.margin)
        }
        .onAppear { desktopReadiness = readiness() }
        .onReceive(readinessTimer) { _ in desktopReadiness = readiness() }
        .onExitCommand { session.cancel() }
    }
    @ViewBuilder private var lessonContent: some View {
        switch session.lesson {
        case .pointer:
            VStack(alignment: .leading, spacing: Space.md) {
                Button(session.pointerOn ? "Turn Practice Pointer Off" : "Turn Practice Pointer On") { session.pointerOn.toggle() }
                if session.pointerOn {
                    PracticePointerCanvas(configuration: session.pointerConfiguration).frame(height: 220)
                } else {
                    Text("Practice Pointer Off. Turn it on to see the sample.")
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
                Text(session.pointerOn ? "Practice Pointer On. Your desktop pointer stays as it is." : "Pointer On and Interact are separate controls.").font(.callout)
            }
        case .interact, .drawing:
            VStack(alignment: .leading, spacing: Space.md) {
                Toggle("Interact in Practice", isOn: $session.interactOn).toggleStyle(.switch)
                if session.lesson == .interact {
                    Button("Try This Button") { session.clickPracticeButton() }.disabled(!session.interactOn)
                    Text(session.interactOn ? "Button clicks received: \(session.clicks)" : "Interact Off. The canvas captures practice drawing; app clicks wait until Interact is on.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
                DrawingPracticeCanvas(session: session.drawing, configuration: session.drawingConfiguration, replay: session.replay)
                    .frame(height: 180)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: Space.sm).strokeBorder(Color.primary.opacity(0.16)))
                HStack(spacing: Space.sm) {
                    Button("Undo") { session.drawing.undo() }.disabled(session.annotationCount == 0)
                    Button("Clear") { session.drawing.clear() }.disabled(session.annotationCount == 0)
                    Text("Practice annotations: \(session.annotationCount)").font(.callout)
                }
                Text(session.interactOn ? "Interact On. Dragging leaves practice ink unchanged." : "Interact Off. Drag to draw; Escape cancels the current line.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        case .radial:
            VStack(alignment: .leading, spacing: Space.md) {
                LocalRadialPracticeCanvas(session: session).frame(height: 280)
                Text(session.radialFeedback).font(.callout).fixedSize(horizontal: false, vertical: true)
                // Native buttons provide the same hold/move/release path with a keyboard or VoiceOver.
                HStack(spacing: Space.sm) {
                    Button("Hold Menu") { session.beginRadial() }.disabled(session.radial != nil)
                    Button("Move to Tools") { session.moveRadialToTools() }.disabled(session.radial == nil)
                    Button("Move to Pen") { session.moveRadialToPen() }.disabled(session.radial?.group == nil)
                    Button("Release") { session.releaseRadial() }.disabled(session.radial == nil)
                    Button("Cancel") { session.cancelRadial() }.disabled(session.radial == nil)
                }
            }
        }
    }
}

private struct PracticePointerCanvas: NSViewRepresentable {
    let configuration: PointerPreviewConfiguration
    final class Coordinator {
        weak var view: PointerPreviewView?
        private var observer: Any?
        init() {
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] notification in
                guard let view = self?.view, notification.object as? NSWindow === view.window else { return }
                view.stop()
            }
        }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> PointerPreviewView {
        let view = PointerPreviewView(configuration: configuration)
        context.coordinator.view = view
        return view
    }
    func updateNSView(_ view: PointerPreviewView, context: Context) { view.configure(configuration, tap: 0, motion: 0) }
    static func dismantleNSView(_ view: PointerPreviewView, coordinator: ()) { view.stop() }
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
        setAccessibilityHelp("Hold the center, drag right through Tools, then up to Pen and release. Keyboard users can use the Hold Menu, Move and Release buttons below.")
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
        let ring = NSBezierPath(ovalIn: CGRect(x: center.x - 216 * scale, y: center.y - 216 * scale, width: 432 * scale, height: 432 * scale))
        ring.stroke()
        for (slot, item) in radial.items.enumerated() where item.enabled {
            let point = displayPoint(RadialGeometry.point(slot: slot, radius: radial.group == nil ? 128 : 216, center: radial.geometry.center))
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
