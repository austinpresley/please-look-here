import AppKit

/// Fixed screen geometry and gesture state, independent of windows and event taps.
struct RadialGeometry {
    static let size: CGFloat = 592
    static let centerRadius: CGFloat = 48
    static let rootRadius: CGFloat = 128
    static let childRadius: CGFloat = 216
    let frame: CGRect
    let center: CGPoint
    let shifted: Bool

    init(cursor: CGPoint, bounds: CGRect) {
        let half = Self.size / 2
        let x = min(max(cursor.x, bounds.minX + half), bounds.maxX - half)
        let y = min(max(cursor.y, bounds.minY + half), bounds.maxY - half)
        center = CGPoint(x: x, y: y)
        frame = CGRect(x: x - half, y: y - half, width: Self.size, height: Self.size)
        shifted = hypot(x - cursor.x, y - cursor.y) > 1
    }
    func distance(_ point: CGPoint) -> CGFloat { hypot(point.x - center.x, point.y - center.y) }
    static func direction(_ point: CGPoint, from center: CGPoint) -> Int {
        let angle = atan2(point.x - center.x, point.y - center.y)
        return (Int((angle / (.pi / 4)).rounded()) + 8) % 8
    }
    static func point(slot: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let a = CGFloat(slot) * .pi / 4
        return CGPoint(x: center.x + sin(a) * radius, y: center.y + cos(a) * radius)
    }
}

struct RadialItem {
    let id: String
    let title: String
    let symbol: String
    var selected = false
    var enabled = true
    var style: PointerStyle? = nil
    var request: [String: Any]? = nil
    var group: String? = nil
}

struct RadialSession {
    let geometry: RadialGeometry
    let root: [RadialItem]
    let groups: [String: [RadialItem]]
    private(set) var group: String?
    private(set) var page = 0
    private(set) var armed: Bool
    private(set) var pageArmed = true
    private(set) var highlighted: Int?
    private(set) var point: CGPoint

    init(geometry: RadialGeometry, root: [RadialItem], groups: [String: [RadialItem]]) {
        self.geometry = geometry; self.root = root; self.groups = groups
        armed = !geometry.shifted; point = geometry.center
    }
    var title: String { group.map { $0.capitalized } ?? "Quick controls" }
    var pages: Int { max(1, ((groups[group ?? ""]?.count ?? 0) + 5) / 6) }
    var items: [RadialItem] {
        guard let group else { return root }
        let all = groups[group] ?? []
        var result = Array(all.dropFirst(page * 6).prefix(6))
        if pages > 1 {
            while result.count < 6 { result.append(RadialItem(id: "empty-\(result.count)", title: "", symbol: "", enabled: false)) }
            result.append(RadialItem(id: "previous", title: "Previous", symbol: "chevron.left", enabled: page > 0))
            result.append(RadialItem(id: "next", title: "Next", symbol: "chevron.right", enabled: page + 1 < pages))
        }
        return result
    }
    var candidate: RadialItem? {
        guard armed, pageArmed, let highlighted, items.indices.contains(highlighted), items[highlighted].enabled else { return nil }
        return items[highlighted].request == nil ? nil : items[highlighted]
    }
    mutating func activate(_ slot: Int) -> [String: Any]? {
        guard items.indices.contains(slot), items[slot].enabled else { return nil }
        let item = items[slot]
        if let child = item.group { group = child; page = 0; pageArmed = true; armed = true }
        else if item.id == "previous" || item.id == "next" { page += item.id == "next" ? 1 : -1; pageArmed = true }
        highlighted = nil
        return item.request
    }
    mutating func back() { group = nil; page = 0; highlighted = nil; pageArmed = true }
    mutating func move(_ point: CGPoint) {
        self.point = point
        let r = geometry.distance(point)
        highlighted = nil
        if !armed { if r <= RadialGeometry.centerRadius { armed = true }; return }
        if group != nil && r < 88 { group = nil; page = 0; pageArmed = true }
        if !pageArmed { if r < 156 { pageArmed = true }; return }
        let slot = RadialGeometry.direction(point, from: geometry.center)
        guard r >= (group == nil ? 100 : 176), r <= 288, items.indices.contains(slot), items[slot].enabled else { return }
        let item = items[slot]
        if let child = item.group { group = child; page = 0; return }
        if item.id == "previous" || item.id == "next" {
            page += item.id == "next" ? 1 : -1
            pageArmed = false
            return
        }
        highlighted = slot
    }
}
