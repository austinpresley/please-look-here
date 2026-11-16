import Foundation

enum DeckAction: String, CaseIterable {
    case pointer = "com.austinpresley.lookhereplease.pointer"
    case interact = "com.austinpresley.lookhereplease.interact"
    case choosePointer = "com.austinpresley.lookhereplease.choose-pointer"
    case selectPointer = "com.austinpresley.lookhereplease.select-pointer"
    case chooseTool = "com.austinpresley.lookhereplease.choose-tool"
}

enum ToolChoice: String, CaseIterable {
    case cycle, pen, rectangle, arrow, text, number, eraser, highlighter
    var title: String { self == .cycle ? "Cycle tools" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .cycle: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .pen: return "pencil.tip"
        case .rectangle: return "rectangle"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .number: return "number.circle"
        case .eraser: return "eraser"
        case .highlighter: return "highlighter"
        }
    }
}

enum PointerDirection: String { case forward, backward }

/// Immutable queued command, captured at the press rather than at dispatch.
enum SelectionCommand: Equatable {
    case cyclePointer, cyclePointerBackward, cycleTool, tool(ToolChoice)
    var request: [String: Any] {
        switch self {
        case .cyclePointer: return ["version": 1, "operation": "cycle-pointer"]
        case .cyclePointerBackward: return ["version": 1, "operation": "cycle-pointer", "direction": "backward"]
        case .cycleTool: return ["version": 1, "operation": "cycle-tool"]
        case .tool(let tool): return ["version": 1, "operation": "tool", "tool": tool.rawValue]
        }
    }
}

struct KeySettings: Equatable {
    var style: String?
    var activate = true
    var toolChoice: ToolChoice? = .cycle
    var pointerDirection: PointerDirection? = .forward

    init(style: String? = nil, activate: Bool = true) {
        self.style = style
        self.activate = activate
    }

    init(_ payload: [String: Any]?) {
        style = (payload?["style"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        activate = payload?["activate"] as? Bool ?? true
        if let saved = payload?["direction"] {
            pointerDirection = (saved as? String).flatMap(PointerDirection.init(rawValue:))
        }
        if let saved = payload?["tool"] {
            toolChoice = (saved as? String).flatMap(ToolChoice.init(rawValue:))
        }
    }
}

/// Only values the app acknowledged. Nothing here is inferred from a key press.
struct Observed: Equatable {
    var active: Bool
    var interact: Bool
    var style: String
    var accessibility: Bool
    var tool: ToolChoice?
    var capturing: Bool?

    init(active: Bool, interact: Bool, style: String, accessibility: Bool, tool: ToolChoice? = .pen, capturing: Bool? = false) {
        self.active = active
        self.interact = interact
        self.style = style
        self.accessibility = accessibility
        self.tool = tool
        self.capturing = capturing
    }

    init?(_ state: [String: Any]?) {
        guard let active = state?["active"] as? Bool, let interact = state?["interact"] as? Bool,
              let style = state?["style"] as? String, let accessibility = state?["accessibility"] as? Bool else { return nil }
        let tool = (state?["tool"] as? String).flatMap(ToolChoice.init(rawValue:)).flatMap { $0 == .cycle ? nil : $0 }
        self.init(active: active, interact: interact, style: style, accessibility: accessibility, tool: tool, capturing: state?["capturing"] as? Bool)
    }
}

enum Link: Equatable {
    case checking
    case connected(Observed)
    /// A read failed. The last observation stays visible with a stale mark.
    case reconnecting(Observed)
    case stopped
    case unavailable

    var observation: Observed? {
        switch self {
        case .connected(let value), .reconnecting(let value): return value
        default: return nil
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

struct LinkTracker {
    static let allowedMisses = 2
    private(set) var link = Link.checking
    private var misses = 0

    mutating func observed(_ value: Observed) {
        misses = 0
        link = .connected(value)
    }

    mutating func appStopped() {
        misses = 0
        link = .stopped
    }

    mutating func unreadable() {
        misses += 1
        if let last = link.observation, misses <= Self.allowedMisses { link = .reconnecting(last) } else { link = .unavailable }
    }
}

enum Transient: Equatable {
    case pending, accepted, uncertain
    case rejected(String)
}

struct KeyFace: Equatable {
    enum Glyph: Equatable { case interactOn, interactOff, style(String), tool(ToolChoice), laser, choose, missing, stopped, noReply, checking }
    enum Tone { case active, idle, muted, warning }
    enum Badge { case selected, locked, busy, stale }
    enum Mark { case pending, accepted, rejected, uncertain }

    var glyph: Glyph
    var label: String
    var tone: Tone
    var badge: Badge?
    var mark: Mark?
    var detail: String?
    var pressed = false
}

enum KeyModel {
    static func selectionCommand(action: DeckAction, settings: KeySettings) -> Result<SelectionCommand, Refusal> {
        if action == .choosePointer {
            guard let direction = settings.pointerDirection else { return .failure(Refusal(text: "Choose Direction")) }
            return .success(direction == .forward ? .cyclePointer : .cyclePointerBackward)
        }
        guard action == .chooseTool, let choice = settings.toolChoice else { return .failure(Refusal(text: "Choose Tool")) }
        return .success(choice == .cycle ? .cycleTool : .tool(choice))
    }
    /// The JSON request for a press, or the reason it cannot be sent.
    static func request(action: DeckAction, settings: KeySettings, link: Link) -> Result<[String: Any], Refusal> {
        switch action {
        case .pointer:
            return .success(["version": 1, "operation": "toggle"])
        case .choosePointer, .chooseTool:
            return selectionCommand(action: action, settings: settings).map(\.request)
        case .interact:
            // The protocol sets an explicit value, so never derive one from a stale sample.
            guard case .connected(let observed) = link else { return .failure(Refusal(text: unavailableText(link))) }
            return .success(["version": 1, "operation": "interact", "enabled": !observed.interact])
        case .selectPointer:
            guard let style = settings.style else { return .failure(Refusal(text: "Choose Pointer")) }
            return .success(["version": 1, "operation": "style", "style": style, "activate": settings.activate])
        }
    }

    struct Refusal: Error, Equatable { let text: String }

    static func unavailableText(_ link: Link) -> String {
        link == .stopped ? "Not running" : "No reply"
    }

    static func rejectionText(code: String?) -> String {
        switch code {
        case "accessibility": return "Allow Drawing"
        case "capturing": return "Capturing"
        case "unavailable": return "Busy"
        case "unknown-style", "missing-asset": return "Missing"
        case "disabled-style": return "Disabled"
        case "no-enabled-pointer": return "Enable Pointer"
        case "activation-failed": return "Can't start"
        default: return "Failed"
        }
    }

    static func face(action: DeckAction, settings: KeySettings, link: Link, styleNames: [String: String], transient: Transient?, pressed: Bool) -> KeyFace {
        var face: KeyFace
        switch link {
        case .checking: face = KeyFace(glyph: .checking, label: "Checking", tone: .muted)
        case .stopped: face = KeyFace(glyph: .stopped, label: "Not running", tone: .muted)
        case .unavailable: face = KeyFace(glyph: .noReply, label: "No reply", tone: .warning)
        case .connected(let observed), .reconnecting(let observed):
            face = observedFace(action: action, settings: settings, observed: observed, styleNames: styleNames)
            if case .reconnecting = link { face.badge = .stale }
        }
        let fixedTool = action == .chooseTool && settings.toolChoice != nil && settings.toolChoice != .cycle
        if fixedTool, let target = settings.toolChoice {
            // Keep the press destination visible even when observation is unavailable.
            if link.observation == nil { face.detail = face.label }
            face.glyph = .tool(target)
            face.label = target.title
            if case .reconnecting = link { face.tone = .idle }
        }
        switch transient {
        case .pending: face.mark = .pending
        case .accepted: face.mark = .accepted
        case .uncertain:
            face.mark = .uncertain
            if fixedTool { face.detail = "Check app" } else { face.label = "Check app" }
        case .rejected(let text):
            face.mark = .rejected
            if fixedTool { face.detail = text } else { face.label = text }
        case nil: break
        }
        face.pressed = pressed
        return face
    }

    private static func observedFace(action: DeckAction, settings: KeySettings, observed: Observed, styleNames: [String: String]) -> KeyFace {
        switch action {
        case .pointer, .choosePointer:
            if action == .choosePointer && settings.pointerDirection == nil {
                return KeyFace(glyph: .missing, label: "Choose Direction", tone: .warning)
            }
            return observed.active
                ? KeyFace(glyph: observed.style == "laser" ? .laser : .style(observed.style), label: "On", tone: .active, badge: .selected)
                : KeyFace(glyph: observed.style == "laser" ? .laser : .style(observed.style), label: "Off", tone: .idle)
        case .interact:
            if observed.interact {
                return KeyFace(glyph: .interactOn, label: "Interact On", tone: .active, badge: observed.accessibility ? .selected : .locked)
            }
            return KeyFace(glyph: .interactOff, label: "Interact Off", tone: .idle)
        case .selectPointer:
            guard let style = settings.style else { return KeyFace(glyph: .choose, label: "Choose", tone: .warning) }
            if !styleNames.isEmpty && styleNames[style] == nil { return KeyFace(glyph: .missing, label: "Missing", tone: .warning) }
            let selected = observed.style == style
            return KeyFace(glyph: style == "laser" ? .laser : .style(style), label: styleNames[style] ?? "", tone: selected ? .active : .idle, badge: selected ? .selected : nil)
        case .chooseTool:
            guard let choice = settings.toolChoice else { return KeyFace(glyph: .missing, label: "Choose Tool", tone: .warning) }
            guard let tool = observed.tool, let capturing = observed.capturing else {
                return choice == .cycle
                    ? KeyFace(glyph: .missing, label: "Tool unknown", tone: .warning)
                    : KeyFace(glyph: .tool(choice), label: choice.title, tone: .warning, detail: "Tool unknown")
            }
            let target = choice == .cycle ? tool : choice
            let ready = target == tool && observed.active && !observed.interact && observed.accessibility && !capturing
            return KeyFace(glyph: .tool(target), label: target.title,
                           tone: ready ? .active : .idle,
                           badge: !observed.accessibility ? .locked : capturing ? .busy : ready ? .selected : nil,
                           detail: "\(observed.active ? "On" : "Off") · \(observed.interact ? "Interact" : "Draw")")
        }
    }
}

/// Only unsent deliberate press intents wait here. An uncertain sent mutation is
/// removed forever; a later successful status read releases the remaining intents.
struct CycleQueue {
    struct Intent: Equatable {
        let context: String
        let keyID: UUID
        var command: SelectionCommand = .cyclePointer
    }
    private(set) var waiting: [Intent] = []
    private(set) var inFlight: Intent?
    private(set) var paused = false

    mutating func enqueue(_ intent: Intent) { waiting.append(intent) }

    mutating func takeNext() -> Intent? {
        guard !paused, inFlight == nil, !waiting.isEmpty else { return nil }
        let next = waiting.removeFirst()
        inFlight = next
        return next
    }

    mutating func finish(uncertain: Bool) {
        inFlight = nil
        paused = uncertain
    }

    mutating func statusConfirmed() { paused = false }
    mutating func cancel(context: String) { waiting.removeAll { $0.context == context } }
    mutating func cancelAll() -> [Intent] {
        let cancelled = waiting
        waiting.removeAll()
        paused = false
        return cancelled
    }
}
