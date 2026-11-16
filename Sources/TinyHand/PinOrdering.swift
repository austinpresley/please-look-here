import Foundation

/// One-step moves preserve the same pin membership, capacity and selection.
enum PinOrdering {
    enum Direction: Int { case left = -1, right = 1 }

    static func moving(_ style: PointerStyle, direction: Direction, in order: [PointerStyle]) -> [PointerStyle]? {
        guard let index = order.firstIndex(of: style) else { return nil }
        let destination = index + direction.rawValue
        guard order.indices.contains(destination) else { return nil }
        var moved = order
        moved.swapAt(index, destination)
        return moved
    }
}

extension SettingsModel {
    func canMovePin(_ style: PointerStyle, direction: PinOrdering.Direction) -> Bool {
        dragging == nil && PinOrdering.moving(style, direction: direction, in: Preferences.pinnedStyles) != nil
    }

    @discardableResult
    func movePin(_ style: PointerStyle, direction: PinOrdering.Direction) -> Bool {
        guard dragging == nil,
              let order = PinOrdering.moving(style, direction: direction, in: Preferences.pinnedStyles) else { return false }
        Preferences.pinnedStyles = order
        pinMessage = nil
        return true
    }
}
