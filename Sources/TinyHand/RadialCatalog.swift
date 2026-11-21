import Foundation

/// Raw identities survive disabled styles, missing artwork and custom removal.
enum RadialFavorites {
    static let storageKey = "quickControlFavorites"
    static let defaults = ["glove", "lavender", "coral", "plush", "robot", "laser"]
    static func valid(_ ids: [String]) -> Bool {
        ids.count == 6 && Set(ids).count == 6 && ids.allSatisfy(validID)
    }
    private static func validID(_ id: String) -> Bool {
        !["all", "back"].contains(id) && PointerConfigurationDocument.validID(id)
    }
    static func load(from storage: UserDefaults, materializeDefaults: Bool = false) -> [String] {
        if let ids = storage.stringArray(forKey: storageKey), valid(ids) { return ids }
        if materializeDefaults { storage.set(defaults, forKey: storageKey) }
        return defaults
    }
    static func assigning(_ id: String, to slot: Int, in ids: [String]) -> [String]? {
        guard valid(ids), ids.indices.contains(slot), validID(id) else { return nil }
        var result = ids
        if let other = result.firstIndex(of: id) { result.swapAt(slot, other) }
        else { result[slot] = id }
        return result
    }
}

struct RadialCurrentState {
    var pointerID: String
    var ink: InkChoice
    var tool: DrawingTool
    var interact: Bool
    var tapSound: Bool
    var muted: Bool
    var toolbar: Bool
}

/// Catalog construction takes snapshots; the state machine never reads defaults.
enum RadialCatalog {
    static var back: RadialItem {
        RadialItem(id: "back", role: .back, title: "Back", symbol: "arrow.uturn.backward", subtitle: "To Quick controls")
    }
    static func make(geometry: RadialGeometry, state: RadialCurrentState, favorites: [String],
                     pointers: [PointerCatalog.Entry], canUndo: Bool, canRedo: Bool, hasInk: Bool,
                     mode: RadialMode = .held) -> RadialSession {
        func command(_ role: RadialItemRole, _ id: String, _ title: String, _ symbol: String, _ operation: String,
                     _ fields: [String: Any] = [:], reason: String = "", subtitle: String = "") -> RadialItem {
            RadialItem(id: id, role: role, title: title, symbol: symbol,
                       request: fields.merging(["version": 1, "operation": operation]) { _, new in new }, reason: reason, subtitle: subtitle)
        }
        let root = [RadialItem(id: "pointer", role: .root(.pointer), title: "Pointer", symbol: "hand.point.up.left.fill", group: "pointer"),
                    RadialItem(id: "color", role: .root(.color), title: "Color", symbol: "paintpalette.fill", group: "color"),
                    RadialItem(id: "draw", role: .root(.draw), title: "Draw", symbol: "pencil.tip", group: "draw"),
                    command(.root(.clear), "clear", "Clear drawing", "trash", "clear", reason: "Nothing to clear", subtitle: "Undo restores it"),
                    command(.root(.interact), "interact", "Cursor", "cursorarrow", "interact"),
                    command(.root(.screenshot), "screenshot", "Screenshot", "camera", "capture", subtitle: "Capture this display"),
                    command(.root(.undo), "undo", "Undo", "arrow.uturn.backward", "undo", reason: "Nothing to undo", subtitle: "Undo last change"),
                    RadialItem(id: "more", role: .root(.more), title: "More", symbol: "ellipsis", group: "more", subtitle: "Redo, sound, toolbar, Settings")]
        let slots = RadialFavorites.valid(favorites) ? favorites : RadialFavorites.defaults
        // Back is south. Clockwise choices start southwest, preserving six slots.
        let pointerItems = [4, 5].map { slots[$0] }.map(pointer) + [RadialItem(id: "all", role: .allPointers, title: "All pointers…", symbol: "square.grid.2x2", subtitle: "Browse and search")] + [0, 1, 2, 3].map { slots[$0] }.map(pointer)
        func pointer(_ id: String) -> RadialItem {
            let entry = pointers.first { $0.style.rawValue == id }
            return RadialItem(id: id, role: .pointerFavorite(id), title: entry?.style.title ?? id, symbol: entry?.style.symbol ?? "questionmark",
                              enabled: entry?.selectable ?? false, style: entry?.style,
                              request: ["version": 1, "operation": "style", "style": id],
                              reason: entry == nil || entry?.available == false ? "Pointer unavailable" : (entry?.enabled == false ? "Disabled in Settings" : ""))
        }
        // Do not filter disabled/unavailable favorites or collapse their positions.
        let colors = InkChoice.allCases.map { command(.ink($0), $0.rawValue, $0.title, "paintpalette", "configure", ["settings": ["ink": $0.rawValue]]) }
        // Match v9's explicit order rather than DrawingTool's historical order.
        let tools: [DrawingTool] = [.pen, .highlighter, .rectangle, .arrow, .text, .number, .eraser]
        let draw = tools.map { command(.tool($0), $0.rawValue, $0.title, $0.symbol, "tool", ["tool": $0.rawValue]) }
        let more = [command(.more(.redo), "redo", "Redo", "arrow.uturn.forward", "redo", reason: "Nothing to redo", subtitle: "Redo last change"),
                    command(.more(.sound), "sound", "Tap sound", "speaker.wave.2", "toggle-current-sound"),
                    command(.more(.mute), "mute", "Mute all sounds", "speaker.slash", "configure"),
                    command(.more(.toolbar), "toolbar", "Toolbar", "rectangle.topthird.inset.filled", "configure"),
                    command(.more(.settings), "settings", "Settings…", "gearshape", "settings", subtitle: "Opens Settings"),
                    command(.more(.off), "off", "Pointer off", "power", "off", subtitle: "Hides the pointer")]
        var session = RadialSession(geometry: geometry, root: root, groups: ["pointer": pointerItems, "color": colors, "draw": draw, "more": more], mode: mode)
        session.updateCurrent(state)
        session.updateHistory(canUndo: canUndo, canRedo: canRedo, hasInk: hasInk)
        return session
    }
    static func refresh(_ original: RadialItem, state: RadialCurrentState, mode: RadialMode) -> RadialItem {
        var item = original
        let open = mode == .held ? "Move out to open" : "Click to open"
        switch item.role {
        case .pointerFavorite(let id):
            item.selected = id == state.pointerID
            item.subtitle = item.selected ? "Current pointer" : ""
        case .ink(let ink):
            item.selected = ink == state.ink
            item.subtitle = item.selected ? "Current ink" : (ink == .match ? "Uses the pointer's ink" : "")
        case .tool(let tool):
            item.selected = tool == state.tool
            item.subtitle = state.interact ? "Starts drawing" : (item.selected ? "Current tool" : "")
            item.accessibilityDetail = state.interact ? "Selects a drawing tool" : ""
        case .more(.sound):
            item.selected = state.tapSound; item.pendingTitle = state.tapSound ? "Turn tap sound off" : "Turn tap sound on"
        case .more(.mute):
            item.selected = state.muted; item.pendingTitle = state.muted ? "Unmute sounds" : "Mute all sounds"
            item.request?["settings"] = ["soundMuted": !state.muted]
        case .more(.toolbar):
            item.selected = state.toolbar; item.pendingTitle = state.toolbar ? "Hide toolbar" : "Show toolbar"
            item.request?["settings"] = ["showToolbar": !state.toolbar]
        case .root(.pointer): item.subtitle = open
        case .root(.draw): item.subtitle = open; item.selected = !state.interact
        case .root(.color): item.subtitle = "Ink: \(state.ink.title)"
        case .root(.interact):
            item.selected = state.interact; item.pendingTitle = "Cursor"
            item.subtitle = "Use apps normally"; item.request?["enabled"] = true
        default: break
        }
        return item
    }
}
