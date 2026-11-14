import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct ToolbarTests {
    @Test func disabledToolbarCannotReturnAfterPointerReactivation() throws {
        _ = NSApplication.shared
        Preferences.pointerMode = .point
        Preferences.showToolbar = true
        let overlay = OverlayController()
        defer { overlay.deactivate() }
        #expect(overlay.activate())
        let panel = overlay.windowsForTesting[1]
        #expect(overlay.toolbarVisible)
        #expect(panel.isVisible && panel.alphaValue == 1)
        overlay.deactivate()
        Preferences.showToolbar = false
        #expect(overlay.activate())
        #expect(!overlay.toolbarVisible)
        #expect(!panel.isVisible || panel.alphaValue == 0)
    }

    @Test func disabledToolbarStaysHiddenOnFirstActivationAndModeChanges() {
        _ = NSApplication.shared
        Preferences.pointerMode = .point
        Preferences.showToolbar = false
        let overlay = OverlayController(accessibility: { false })
        defer { overlay.deactivate() }
        #expect(overlay.activate())
        let panel = overlay.windowsForTesting[1]
        #expect(!panel.isVisible && panel.alphaValue == 0 && panel.ignoresMouseEvents)
        #expect(!overlay.setMode(.draw))
        #expect(overlay.setMode(.point))
        #expect(!overlay.toolbarVisible)
        #expect(!panel.isVisible && panel.alphaValue == 0)
    }

    @Test func preferenceChangesReconcileThePanelImmediately() {
        _ = NSApplication.shared
        Preferences.pointerMode = .point
        Preferences.showToolbar = false
        let overlay = OverlayController()
        defer { overlay.deactivate() }
        #expect(overlay.activate())
        let panel = overlay.windowsForTesting[1]
        Preferences.showToolbar = true
        #expect(overlay.toolbarVisible && panel.isVisible && panel.alphaValue == 1)
        #expect(!panel.ignoresMouseEvents)
        Preferences.showToolbar = false
        #expect(!overlay.toolbarVisible && !panel.isVisible && panel.alphaValue == 0)
        #expect(panel.ignoresMouseEvents)
        overlay.toggleToolbar()
        #expect(Preferences.showToolbar && overlay.toolbarVisible)
        overlay.toggleToolbar()
        #expect(!Preferences.showToolbar && !overlay.toolbarVisible && !panel.isVisible)
    }

}
