import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct InteractionTests {
    @Test func handVisibilityDefaultsAndResetRespectExplicitChoices() {
        Preferences.storage.removeObject(forKey: "interactKeepsHand")
        #expect(Preferences.interactKeepsHand)
        Preferences.interactKeepsHand = false
        #expect(!Preferences.interactKeepsHand)
        Preferences.resetAll()
        #expect(Preferences.interactKeepsHand)
        #expect(Preferences.pointerMode.isInteractive)
    }

    @Test func hidingOnlyAppliesToNativePressesAndRestoresOnRelease() {
        #expect(!PointerMode.point.hidesPointer(whilePressing: true, keepsHand: true))
        #expect(PointerMode.point.hidesPointer(whilePressing: true, keepsHand: false))
        #expect(!PointerMode.point.hidesPointer(whilePressing: false, keepsHand: false))
        #expect(!PointerMode.draw.hidesPointer(whilePressing: true, keepsHand: false))
    }
}
