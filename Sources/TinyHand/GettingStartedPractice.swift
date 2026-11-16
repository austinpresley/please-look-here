import AppKit
import Combine

/// Destinations only. Opening one never starts a ShortcutRecorder or assigns keys.
enum PracticeShortcutTarget: String, CaseIterable, Identifiable {
    case pointer = "toggle", interact = "mode", drawing = "pen", radial = "radial"
    var id: String { rawValue }
    var controlIdentifier: String { "settings.shortcut.\(rawValue)" }
    var title: String {
        switch self {
        case .pointer: return "Turn pointer on or off"
        case .interact: return "Toggle Interact"
        case .drawing: return "Pen Tool"
        case .radial: return "Hold to open"
        }
    }
}

struct ShortcutFocusRequest: Equatable {
    let target: PracticeShortcutTarget
    let id = UUID()
}

enum PracticeLesson: Int, CaseIterable {
    case pointer, interact, drawing, radial
    var title: String {
        switch self {
        case .pointer: return "Turn the pointer on"
        case .interact: return "Use apps with Interact"
        case .drawing: return "Draw with Interact off"
        case .radial: return "Hold, move, release"
        }
    }
    var instruction: String {
        switch self {
        case .pointer: return "Turn on the sample pointer, then move or click inside its preview. Pointer On controls visibility."
        case .interact: return "With Interact on, clicks reach the app. Try the button, then turn Interact off and draw below."
        case .drawing: return "Drag below to add a line. Undo and Clear affect only this practice ink. Turn Interact on to stop drawing."
        case .radial: return "Hold the center, move right through Tools, then up to Pen. Release to choose. Return to the center or press Escape to cancel."
        }
    }
    var shortcutTarget: PracticeShortcutTarget {
        switch self {
        case .pointer: return .pointer
        case .interact: return .interact
        case .drawing: return .drawing
        case .radial: return .radial
        }
    }
}

/// Read-only desktop readiness, deliberately separate from local practice eligibility.
struct PracticeReadiness: Equatable {
    var drawingAllowed: Bool
    var radialAssigned: Bool
    var capturing: Bool
    func message(for lesson: PracticeLesson) -> String {
        switch lesson {
        case .pointer: return "On your desktop: Show Pointer turns on your current pointer. Interact works without drawing permission."
        case .interact, .drawing:
            if capturing { return "On your desktop: drawing waits until the screenshot finishes. You can keep practicing here." }
            if !drawingAllowed { return "On your desktop: drawing needs Accessibility in Settings > General. Local practice is ready without permission." }
            return "On your desktop: turn Pointer On and Interact off to draw. Close practice first so clicks reach the desktop."
        case .radial:
            var reasons: [String] = []
            if !radialAssigned { reasons.append("choose a Hold to open modifier in Shortcuts") }
            if !drawingAllowed { reasons.append("allow Accessibility in Settings > General") }
            if capturing { reasons.append("wait for the screenshot to finish") }
            let setup = reasons.isEmpty ? "turn Pointer On" : reasons.joined(separator: ", then ") + ", and turn Pointer On"
            return "On your desktop: \(setup). Close this window before using the modifier. This local menu is ready now."
        }
    }
}

/// All mutations stay in this disposable model and its independent drawing session.
final class GettingStartedPracticeSession: ObservableObject {
    @Published private(set) var lesson: PracticeLesson = .pointer
    @Published var pointerOn = false { didSet { reconcileMode() } }
    @Published var interactOn = true { didSet { reconcileMode() } }
    @Published private(set) var clicks = 0
    @Published private(set) var annotationCount = 0
    @Published private(set) var replay = 0
    @Published private(set) var radial: RadialSession?
    @Published private(set) var radialFeedback = "Hold the center to begin."
    let drawing: DrawingPracticeSession
    let pointerConfiguration: PointerPreviewConfiguration
    let drawingConfiguration: DrawingPracticeConfiguration
    private var drawingChanges: AnyCancellable?

    init(pointerConfiguration: PointerPreviewConfiguration) {
        self.pointerConfiguration = pointerConfiguration
        drawingConfiguration = DrawingPracticeConfiguration(tool: .pen, color: AnnotationColor(Ink.purple), width: 8,
            opacity: 1, smoothing: .light, fadeStyle: .permanent, fadeDelay: 3, trailDelay: 1, trailSpeed: 100)
        drawing = DrawingPracticeSession(configuration: drawingConfiguration)
        drawing.mode = .interact
        drawingChanges = drawing.objectWillChange.sink { [weak self] in
            guard let self else { return }
            self.annotationCount = self.drawing.ink.document.annotations.count
        }
    }
    private func reconcileMode() {
        drawing.mode = pointerOn && !interactOn ? .draw : .interact
        cancelRadial()
    }
    func select(_ lesson: PracticeLesson) {
        cancel()
        drawing.clear()
        self.lesson = lesson
        clicks = 0
        pointerOn = lesson != .pointer
        interactOn = lesson != .drawing
        radialFeedback = "Hold the center to begin."
        replay += 1
    }
    func replayStep() { select(lesson) }
    func replayAll() { select(.pointer) }
    func clickPracticeButton() { if pointerOn && interactOn { clicks += 1 } }
    func cancel() { drawing.cancel(); cancelRadial() }
    func stop() { cancel(); drawing.clear() }

    static let radialBounds = CGRect(x: 0, y: 0, width: RadialGeometry.size, height: RadialGeometry.size)
    static var radialTemplate: RadialSession {
        // Keep the real Tools direction and real gesture thresholds. Only this
        // category is taught; these payloads are local IDs, never app commands.
        let empty = RadialItem(id: "empty", title: "", symbol: "", enabled: false)
        let tools = [DrawingTool.pen, .rectangle, .arrow].map {
            RadialItem(id: $0.rawValue, title: $0.title, symbol: $0.symbol, request: ["practiceTool": $0.rawValue])
        }
        return RadialSession(geometry: RadialGeometry(cursor: CGPoint(x: 296, y: 296), bounds: radialBounds),
                             root: [empty, empty, RadialItem(id: "tools", title: "Tools", symbol: "pencil.tip", group: "tools")],
                             groups: ["tools": tools])
    }
    func beginRadial() {
        guard lesson == .radial else { return }
        drawing.cancel()
        radial = Self.radialTemplate
        radialFeedback = "Keep holding. Move right through Tools."
    }
    func moveRadial(to point: CGPoint) {
        guard radial != nil else { return }
        radial?.move(point)
        if let title = radial?.candidate?.title { radialFeedback = "Release to choose \(title) locally." }
        else if radial?.group != nil { radialFeedback = "Move up to Pen. Move inward to go back." }
        else { radialFeedback = "Keep holding. Move right through Tools, or release at the center to cancel." }
    }
    func moveRadialToTools() {
        moveRadial(to: RadialGeometry.point(slot: 2, radius: RadialGeometry.rootRadius, center: Self.radialTemplate.geometry.center))
    }
    func moveRadialToPen() {
        moveRadial(to: RadialGeometry.point(slot: 0, radius: RadialGeometry.childRadius, center: Self.radialTemplate.geometry.center))
    }
    func releaseRadial() {
        guard let radial else { return }
        radialFeedback = radial.candidate.map { "\($0.title) selected in practice. Desktop tool and ink are unchanged." }
            ?? "Cancelled. Hold the center to try again."
        self.radial = nil
    }
    func cancelRadial() {
        if radial != nil { radialFeedback = "Cancelled. Hold the center to try again." }
        radial = nil
    }
}
