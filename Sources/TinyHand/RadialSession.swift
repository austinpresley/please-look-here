import Foundation

/// AppKit coordinates: clockwise degrees from north. No windows or native input.
struct RadialGeometry {
    static let roundingTolerance: CGFloat = 1e-9
    static let size: CGFloat = 384
    static let outerRadius: CGFloat = 164
    static let centerRadius: CGFloat = 52
    static let acquireRadius: CGFloat = 72
    static let retainRadius: CGFloat = 64
    static let enterRadius: CGFloat = 112
    static let rootRadius: CGFloat = 118
    static let childRadius: CGFloat = 118
    let bounds: CGRect
    let center: CGPoint
    let shifted: Bool
    var isValid: Bool {
        [bounds.minX, bounds.minY, bounds.width, bounds.height, center.x, center.y].allSatisfy(\.isFinite) && bounds.width > 0 && bounds.height > 0
    }
    var usesList: Bool { bounds.width < Self.size || bounds.height < Self.size }
    var frame: CGRect { CGRect(x: center.x - Self.size / 2, y: center.y - Self.size / 2, width: Self.size, height: Self.size) }

    init(cursor: CGPoint, bounds: CGRect) {
        self.bounds = bounds
        func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
            low <= high ? min(max(value, low), high) : (low + high) / 2
        }
        let half = Self.size / 2
        center = CGPoint(x: clamp(cursor.x, bounds.minX + half, bounds.maxX - half),
                         y: clamp(cursor.y, bounds.minY + half, bounds.maxY - half))
        shifted = Self.distance(center, cursor) > 8 + Self.roundingTolerance
    }
    func distance(_ point: CGPoint) -> CGFloat { Self.distance(point, center) }
    func contains(_ point: CGPoint) -> Bool {
        point.x.isFinite && point.y.isFinite && point.x >= bounds.minX && point.x <= bounds.maxX && point.y >= bounds.minY && point.y <= bounds.maxY
    }
    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
    static func normalize(_ angle: CGFloat) -> CGFloat { (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }
    static func angle(_ point: CGPoint, from center: CGPoint) -> CGFloat { normalize(atan2(point.x - center.x, point.y - center.y) * 180 / .pi) }
    static func difference(_ a: CGFloat, _ b: CGFloat) -> CGFloat { abs(normalize(a - b + 180) - 180) }
    /// A single partition covers the circle, including separator gaps. Snap only
    /// machine-roundoff at an exact boundary, never create shortened intervals.
    static func sector(angle: CGFloat, count: Int, firstAngle: CGFloat = 0) -> Int {
        guard count > 0 else { return 0 }
        let width = 360 / CGFloat(count)
        let offset = normalize(angle - (firstAngle - width / 2)) / width
        let rounded = offset.rounded()
        let stable = abs(offset - rounded) < 1e-12 ? rounded : offset
        return Int(floor(stable)) % count
    }
    static func direction(_ point: CGPoint, from center: CGPoint) -> Int { sector(angle: angle(point, from: center), count: 8) }
    static func point(angle: CGFloat, radius: CGFloat, center: CGPoint) -> CGPoint {
        let a = angle * .pi / 180
        return CGPoint(x: center.x + sin(a) * radius, y: center.y + cos(a) * radius)
    }
    static func point(slot: Int, radius: CGFloat, center: CGPoint) -> CGPoint { point(angle: CGFloat(slot) * 45, radius: radius, center: center) }
}

enum RadialRootCommand: String { case pointer, color, draw, clear, interact, screenshot, undo, more }
enum RadialMoreCommand: String { case redo, sound, mute, toolbar, settings, off }

/// IDs identify saved data and slots; roles identify what an item means.
/// A missing pointer keeps its role even when its ID spells a command name.
enum RadialItemRole: Equatable {
    case root(RadialRootCommand), pointerFavorite(String), ink(InkChoice), tool(DrawingTool)
    case more(RadialMoreCommand), back, allPointers, placeholder

    var isCheckable: Bool {
        switch self {
        case .pointerFavorite, .ink, .tool, .root(.draw), .root(.interact), .more(.sound), .more(.mute), .more(.toolbar): return true
        default: return false
        }
    }
    var hasStateBadge: Bool { false }
    var opensSubmenu: Bool {
        switch self {
        case .root(.pointer), .root(.color), .root(.draw), .root(.more): return true
        default: return false
        }
    }
}

struct RadialItem {
    let id: String
    let role: RadialItemRole
    let title: String
    let symbol: String
    var selected = false
    var enabled = true
    var style: PointerStyle? = nil
    var request: [String: Any]? = nil
    var group: String? = nil
    var reason = ""
    var subtitle = ""
    var pendingTitle: String? = nil
    var opensBrowser: Bool { role == .allPointers }
    var accessibilityDetail = ""
    var isBack: Bool { role == .back }
    var showsCheck: Bool { selected && role.isCheckable && !role.hasStateBadge }
    var isLeaf: Bool { request != nil || opensBrowser }
}

enum RadialMode { case held, persistent }
enum RadialKey: Equatable {
    case tab, left, right, up, down, enter, space, escape, backspace, number(Int)
    static func keyCode(_ code: Int64) -> Self? {
        switch code {
        case 48: return .tab
        case 123: return .left
        case 124: return .right
        case 126: return .up
        case 125: return .down
        case 36, 76: return .enter
        case 49: return .space
        case 53: return .escape
        case 51: return .backspace
        case 18: return .number(1)
        case 19: return .number(2)
        case 20: return .number(3)
        case 21: return .number(4)
        case 23: return .number(5)
        case 22: return .number(6)
        case 26: return .number(7)
        case 28: return .number(8)
        default: return nil
        }
    }
}
struct RadialKeyModifiers: OptionSet {
    let rawValue: Int
    static let shift = Self(rawValue: 1)
    static let command = Self(rawValue: 2)
    static let option = Self(rawValue: 4)
    static let control = Self(rawValue: 8)
}

struct RadialSession {
    let generation = UUID()
    private(set) var geometry: RadialGeometry
    private(set) var root: [RadialItem]
    private(set) var groups: [String: [RadialItem]]
    let mode: RadialMode
    private(set) var group: String?
    private(set) var parent: RadialGeometry?
    private(set) var armed: Bool
    private(set) var needNeutral = false
    private(set) var outside = false
    private(set) var highlighted: Int?
    private(set) var point: CGPoint
    private(set) var keyboard = false
    private(set) var ownsFocus: Bool
    private(set) var closed = false
    private struct SlotIdentity: Equatable {
        let level: String?
        let slot: Int
        let id: String
        let role: RadialItemRole
    }
    private enum Press: Equatable { case outside, hub, item(SlotIdentity) }
    private func identity(at slot: Int) -> SlotIdentity {
        SlotIdentity(level: group, slot: slot, id: items[slot].id, role: items[slot].role)
    }
    private var press: Press?
    private(set) var listScroll: CGFloat = 0
    var listLayout: RadialListLayout { RadialListLayout(bounds: geometry.bounds, center: geometry.center, count: items.count) }
    var panelFrame: CGRect { geometry.usesList ? listLayout.frame : geometry.frame }
    mutating func scrollList(to offset: CGFloat) { listScroll = min(max(0, offset), listLayout.maximumScroll) }

    init(geometry: RadialGeometry, root: [RadialItem], groups: [String: [RadialItem]], mode: RadialMode = .held) {
        self.geometry = geometry; self.root = root; self.groups = groups; self.mode = mode
        armed = !geometry.shifted || geometry.usesList; point = geometry.center
        ownsFocus = mode == .persistent
        closed = !geometry.isValid
    }
    mutating func relinquishFocus() { ownsFocus = false }

    var title: String { group.flatMap { g in root.first { $0.group == g }?.title } ?? "Quick controls" }
    var items: [RadialItem] {
        guard let group else { return root }
        return [RadialCatalog.back] + (groups[group] ?? [])
    }
    var firstAngle: CGFloat {
        guard let group, let index = root.firstIndex(where: { $0.group == group }) else { return 0 }
        return RadialGeometry.normalize(CGFloat(index) * 45 + 180)
    }
    func angle(for index: Int) -> CGFloat { RadialGeometry.normalize(firstAngle + CGFloat(index) * 360 / CGFloat(max(1, items.count))) }
    var inspected: RadialItem? { highlighted.flatMap { items.indices.contains($0) ? items[$0] : nil } }
    var candidate: RadialItem? {
        guard !closed, armed, !needNeutral, !outside, let item = inspected, item.enabled, item.isLeaf else { return nil }
        return item
    }
    var pendingCopy: (title: String, subtitle: String) {
        if outside { return ("Return to this display", "Release cancels") }
        if !armed { return ("Move to the center", "to start") }
        if needNeutral { return ("Quick controls", "Move to the center") }
        if let item = inspected { return (item.pendingTitle ?? item.title, item.enabled ? item.subtitle : item.reason) }
        return (title, group == nil ? (mode == .held ? "Release here cancels" : "Esc closes") : (mode == .held ? "Move to a choice" : "Click a choice"))
    }
    var keyboardOrder: [Int] { group == nil || geometry.usesList ? Array(items.indices) : Array(items.indices.dropFirst()) + [0] }

    mutating func updateHistory(canUndo: Bool, canRedo: Bool, hasInk: Bool) {
        // Validate both the catalog role and slot before updating availability.
        func update(_ items: inout [RadialItem], slot: Int, role: RadialItemRole, operation: String, enabled: Bool) {
            guard items.indices.contains(slot), items[slot].role == role,
                  items[slot].request?["operation"] as? String == operation else { return }
            items[slot].enabled = enabled
        }
        update(&root, slot: 3, role: .root(.clear), operation: "clear", enabled: hasInk)
        update(&root, slot: 6, role: .root(.undo), operation: "undo", enabled: canUndo)
        if var more = groups["more"] {
            update(&more, slot: 0, role: .more(.redo), operation: "redo", enabled: canRedo)
            groups["more"] = more
        }
    }
    /// Refreshes state without changing the catalog, order, or a saved slot.
    mutating func updateCurrent(_ state: RadialCurrentState) {
        root = root.map { RadialCatalog.refresh($0, state: state, mode: mode) }
        for key in groups.keys { groups[key] = groups[key]?.map { RadialCatalog.refresh($0, state: state, mode: mode) } }
    }
    mutating func updatePointers(_ pointers: [PointerCatalog.Entry]) {
        groups["pointer"] = groups["pointer"]?.map { original in
            guard case .pointerFavorite(let id) = original.role else { return original }
            var item = original
            let entry = pointers.first { $0.style.rawValue == id }
            item.enabled = entry?.selectable ?? false
            item.reason = entry == nil || entry?.available == false ? "Pointer unavailable" : (entry?.enabled == false ? "Disabled in Settings" : "")
            return item
        }
    }
    mutating func cancel() { closed = true; highlighted = nil; press = nil }
    mutating func back(needNeutral: Bool = false) {
        guard !closed else { return }
        if let parent { geometry = parent }
        parent = nil; group = nil; highlighted = nil; press = nil; listScroll = 0
        self.needNeutral = needNeutral; armed = true
    }
    private mutating func enter(_ child: String, at point: CGPoint, keyboard: Bool) {
        parent = geometry; group = child; highlighted = nil; press = nil; needNeutral = false; listScroll = 0
        geometry = RadialGeometry(cursor: point, bounds: geometry.bounds)
        armed = keyboard || !geometry.shifted || geometry.usesList
        self.keyboard = keyboard
    }
    /// AX and keyboard activation bypass pointer arming, but never availability.
    mutating func activate(_ slot: Int, viaKeyboard: Bool = true) -> RadialItem? {
        guard !closed, items.indices.contains(slot), items[slot].enabled else { return nil }
        let item = items[slot]
        if viaKeyboard { ownsFocus = true; keyboard = true; outside = false; armed = true; needNeutral = false }
        if let child = item.group {
            let origin = viaKeyboard ? RadialGeometry.point(angle: angle(for: slot), radius: RadialGeometry.enterRadius, center: geometry.center) : point
            enter(child, at: origin, keyboard: viaKeyboard)
        } else if item.isBack { back(); keyboard = viaKeyboard }
        else if item.isLeaf { cancel(); return item }
        return nil
    }
    mutating func release() -> RadialItem? {
        guard !closed else { return nil }
        let item = candidate
        cancel()
        return item
    }
    mutating func move(_ point: CGPoint) {
        guard !closed else { return }
        self.point = point; keyboard = false
        outside = !geometry.contains(point)
        let r = geometry.distance(point)
        if outside { highlighted = nil }
        else if !armed { highlighted = nil; if r <= RadialGeometry.centerRadius + RadialGeometry.roundingTolerance { armed = true } }
        else if needNeutral { highlighted = nil; if r <= RadialGeometry.centerRadius + RadialGeometry.roundingTolerance { needNeutral = false } }
        else if mode == .held, group != nil, let parent,
                RadialGeometry.distance(parent.center, geometry.center) >= 104 - RadialGeometry.roundingTolerance,
                parent.distance(point) <= RadialGeometry.centerRadius + RadialGeometry.roundingTolerance { back(); return }
        else if geometry.usesList { highlighted = listLayout.index(at: point, scroll: listScroll) }
        else if mode == .persistent && r > RadialGeometry.outerRadius + RadialGeometry.roundingTolerance { highlighted = nil }
        else if r + RadialGeometry.roundingTolerance < (highlighted == nil ? RadialGeometry.acquireRadius : RadialGeometry.retainRadius) { highlighted = nil }
        else {
            let a = RadialGeometry.angle(point, from: geometry.center)
            var index = RadialGeometry.sector(angle: a, count: items.count, firstAngle: firstAngle)
            if let old = highlighted, items.indices.contains(old), RadialGeometry.difference(a, angle(for: old)) <= 180 / CGFloat(items.count) + 4 { index = old }
            guard items.indices.contains(index) else { highlighted = nil; return }
            highlighted = index
            let item = items[index]
            if mode == .held, item.enabled {
                if let child = item.group, r + RadialGeometry.roundingTolerance >= RadialGeometry.enterRadius { enter(child, at: point, keyboard: false); return }
                if item.isBack { back(needNeutral: true); return }
            }
        }
        if let press, press != target(at: point) { self.press = nil }
    }
    private func target(at point: CGPoint) -> Press? {
        if geometry.usesList {
            guard listLayout.frame.contains(point) else { return .outside }
            return listLayout.index(at: point, scroll: listScroll).map { .item(identity(at: $0)) }
        }
        guard geometry.contains(point), geometry.distance(point) <= RadialGeometry.outerRadius + RadialGeometry.roundingTolerance else { return .outside }
        if geometry.distance(point) + RadialGeometry.roundingTolerance < RadialGeometry.retainRadius { return .hub }
        return highlighted.map { .item(identity(at: $0)) }
    }
    mutating func pointerDown(_ point: CGPoint) {
        guard !closed, mode == .persistent || geometry.usesList else { return }
        move(point); press = target(at: point)
    }
    mutating func pointerUp(_ point: CGPoint) -> RadialItem? {
        guard !closed, mode == .persistent || geometry.usesList else { return nil }
        let original = press
        move(point); press = nil
        guard let original, original == target(at: point) else { return nil }
        switch original {
        case .outside: cancel()
        case .hub: if group == nil { cancel() } else { back() }
        case .item: if armed, let index = highlighted { return activate(index, viaKeyboard: false) }
        }
        return nil
    }
    mutating func pointerCancelled() { press = nil; if mode == .held { cancel() } }
    /// Used by semantic focus and deterministic review. It shares the normal
    /// keyboard ownership policy and never changes availability or activates.
    mutating func inspect(_ index: Int, keyboard: Bool) {
        guard !closed, items.indices.contains(index) else { return }
        highlighted = index; self.keyboard = keyboard
        if keyboard { ownsFocus = true; armed = true; needNeutral = false; outside = false }
    }
    mutating func key(_ key: RadialKey, modifiers: RadialKeyModifiers = []) -> RadialItem? {
        guard !closed, modifiers.intersection([.command, .option, .control]).isEmpty else { return nil }
        if key == .escape { if mode == .held || group == nil { cancel() } else { back(); keyboard = true }; return nil }
        ownsFocus = true
        if key == .backspace {
            if mode == .persistent { if group == nil { cancel() } else { back(); keyboard = true } }
            return nil
        }
        var direction = 0
        if key == .right || (key == .tab && !modifiers.contains(.shift)) || (geometry.usesList && key == .down) { direction = 1 }
        if key == .left || (key == .tab && modifiers.contains(.shift)) || (geometry.usesList && key == .up) { direction = -1 }
        if direction != 0 {
            let order = keyboardOrder
            guard !order.isEmpty else { return nil }
            let position = highlighted.flatMap { order.firstIndex(of: $0) }
            highlighted = order[position.map { ($0 + direction + order.count) % order.count } ?? (direction > 0 ? 0 : order.count - 1)]
            keyboard = true; armed = true; needNeutral = false; outside = false
        } else if case .number(let number) = key, group == nil, (1...8).contains(number), root.indices.contains(number - 1) {
            highlighted = number - 1; keyboard = true; armed = true; needNeutral = false; outside = false
        } else if key == .enter || key == .space, let highlighted { return activate(highlighted) }
        return nil
    }
}
