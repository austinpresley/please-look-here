import Foundation
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct SettingsAccessibilityTests {
    @Test func pinMovesPreserveMembershipAndRejectBoundaries() {
        let pins: [PointerStyle] = [.lavender, .robot, .laser]
        #expect(PinOrdering.moving(.lavender, direction: .left, in: pins) == nil)
        #expect(PinOrdering.moving(.laser, direction: .right, in: pins) == nil)
        #expect(PinOrdering.moving(.coral, direction: .right, in: pins) == nil)
        #expect(PinOrdering.moving(.laser, direction: .left, in: [.laser]) == nil)
        #expect(PinOrdering.moving(.laser, direction: .right, in: []) == nil)
        #expect(PinOrdering.moving(.robot, direction: .left, in: pins) == [.robot, .lavender, .laser])
        #expect(PinOrdering.moving(.robot, direction: .right, in: pins) == [.lavender, .laser, .robot])
        for style in pins {
            for direction in [PinOrdering.Direction.left, .right] {
                if let moved = PinOrdering.moving(style, direction: direction, in: pins) {
                    #expect(Set(moved) == Set(pins))
                    #expect(moved.count == pins.count)
                }
            }
        }
    }

    @Test func keyboardPinMovesKeepSelectionAndEnabledState() {
        Preferences.resetAll()
        defer { Preferences.resetAll() }
        let model = SettingsModel()
        Preferences.pinnedStyles = [.lavender, .robot, .laser]
        Preferences.disabledPointerIDs = ["robot"]
        PointerStyle.saved = .laser
        let disabled = Preferences.disabledPointerIDs
        #expect(!model.canMovePin(.lavender, direction: .left))
        #expect(!model.movePin(.lavender, direction: .left))
        #expect(model.canMovePin(.robot, direction: .right))
        #expect(model.movePin(.robot, direction: .right))
        #expect(Preferences.pinnedStyles == [.lavender, .laser, .robot])
        #expect(PointerStyle.saved == .laser)
        #expect(Preferences.disabledPointerIDs == disabled)
        #expect(model.movePin(.robot, direction: .left))
        #expect(Preferences.pinnedStyles == [.lavender, .robot, .laser])
        #expect(PointerStyle.saved == .laser && Preferences.disabledPointerIDs == disabled)
    }
}
