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
        case .interact: return "Cursor ↔ last tool"
        case .drawing: return "Pen Tool"
        case .radial: return "Hold to open"
        }
    }
}

struct ShortcutFocusRequest: Equatable {
    let target: PracticeShortcutTarget
    var command: String? = nil
    let id = UUID()
    var controlIdentifier: String { command.map { "settings.shortcut.\($0)" } ?? target.controlIdentifier }
}

enum PracticeLesson: Int, CaseIterable {
    case pointer, drawing, interact, radial
    var title: String {
        switch self {
        case .pointer: return "Click through with Cursor"
        case .interact: return "Back to Cursor"
        case .drawing: return "Pick the pen, then draw"
        case .radial: return "Hold, move, release"
        }
    }
    var progressName: String { switch self { case .pointer: return "Cursor"; case .drawing: return "Drawing"; case .interact: return "Back to Cursor"; case .radial: return "Quick controls" } }
    var instruction: String {
        switch self {
        case .pointer: return "Click the sample button with Cursor selected."
        case .interact: return "Choose Cursor, then click the sample button again."
        case .drawing: return "Choose Pen and drag a line in the canvas."
        case .radial: return "Hold the center, move through Draw to Pen, then release."
        }
    }
    var symbol: String {
        switch self { case .pointer: return "cursorarrow.click"; case .drawing: return "pencil.tip"; case .interact: return "cursorarrow"; case .radial: return "scope" }
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
        case .pointer: return "On your desktop: Show Pointer turns on your current pointer. Cursor works without drawing permission."
        case .interact, .drawing:
            if capturing { return "On your desktop: drawing waits until the screenshot finishes. You can keep practicing here." }
            if !drawingAllowed { return "On your desktop: drawing needs Accessibility in Settings > General. Local practice is ready without permission." }
            return "On your desktop: turn the pointer on and choose a drawing tool to draw. Close practice first so clicks reach the desktop."
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
    @Published private(set) var completedSteps: Set<PracticeLesson> = []
    var progressAnnouncement: String { "Step \(lesson.rawValue + 1) of \(PracticeLesson.allCases.count), \(lesson.progressName)" }
    @Published var pointerOn = false { didSet { reconcileMode() } }
    @Published var interactOn = true { didSet { reconcileMode() } }
    @Published private(set) var radialSucceeded = false
    var succeeded: Bool {
        switch lesson { case .pointer, .interact: return clicks > 0; case .drawing: return annotationCount > 0; case .radial: return radialSucceeded }
    }
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
            if self.lesson == .drawing && self.annotationCount > 0 { self.completedSteps.insert(.drawing) }
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
        clicks = 0; radialSucceeded = false
        pointerOn = lesson != .pointer
        interactOn = lesson != .drawing && lesson != .interact
        radialFeedback = "Hold the center to begin."
        replay += 1
    }
    func replayStep() { select(lesson) }
    func replayAll() { completedSteps = []; select(.pointer) }
    func clickPracticeButton() { if pointerOn && interactOn { clicks += 1; completedSteps.insert(lesson) } }
    func cancel() { drawing.cancel(); cancelRadial() }
    func stop() { cancel(); drawing.clear() }

    static let radialBounds = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    static var radialTemplate: RadialSession {
        // Keep the real Tools direction and real gesture thresholds. Only this
        // category is taught; these payloads are local IDs, never app commands.
        let empty = RadialItem(id: "empty", role: .placeholder, title: "", symbol: "", enabled: false)
        let tools = [DrawingTool.pen, .highlighter, .rectangle, .arrow, .text, .number, .eraser].map {
            RadialItem(id: $0.rawValue, role: .tool($0), title: $0.title, symbol: $0.symbol, request: ["practiceTool": $0.rawValue])
        }
        return RadialSession(geometry: RadialGeometry(cursor: CGPoint(x: 296, y: 296), bounds: radialBounds),
                             root: [empty, empty, RadialItem(id: "tools", role: .root(.draw), title: "Draw", symbol: "pencil.tip", group: "tools"), empty, empty, empty, empty, empty],
                             groups: ["tools": tools])
    }
    func beginRadial() {
        guard lesson == .radial else { return }
        drawing.cancel()
        radial = Self.radialTemplate
        radialFeedback = "Keep holding. Move right through Draw."
    }
    func moveRadial(to point: CGPoint) {
        guard radial != nil else { return }
        radial?.move(point)
        if let title = radial?.candidate?.title { radialFeedback = "Release to choose \(title) locally." }
        else if radial?.group != nil { radialFeedback = "Move to Pen. Choose Back to return, then visit the parent center before choosing again." }
        else { radialFeedback = "Keep holding. Move right through Draw, or release at the center to cancel." }
    }
    func moveRadialToTools() {
        moveRadial(to: RadialGeometry.point(slot: 2, radius: RadialGeometry.rootRadius, center: Self.radialTemplate.geometry.center))
    }
    func moveRadialToPen() {
        guard let radial, let index = radial.items.firstIndex(where: { $0.role == .tool(.pen) }) else { return }
        moveRadial(to: RadialGeometry.point(angle: radial.angle(for: index), radius: RadialGeometry.childRadius, center: radial.geometry.center))
    }
    func releaseRadial() {
        guard let radial else { return }
        radialSucceeded = radial.candidate != nil
        if radialSucceeded { completedSteps.insert(.radial) }
        radialFeedback = radial.candidate.map { "\($0.title) selected in practice. Desktop tool and ink are unchanged." }
            ?? "Cancelled. Hold the center to try again."
        self.radial = nil
    }
    func cancelRadial() {
        if radial != nil { radialFeedback = "Cancelled. Hold the center to try again." }
        radial = nil
    }
}
