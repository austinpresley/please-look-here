import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct ShortcutNavigationTests {
    @Test func recorderHasVisibleNativeFocusWithoutStartingRecording() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 240),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let recorder = ShortcutRecorder(shortcut: nil)
        window.contentView?.addSubview(recorder)
        var recording = 0
        var assignments = 0
        recorder.onRecording = { _ in recording += 1 }
        recorder.onChange = { _ in assignments += 1; return true }
        #expect(window.makeFirstResponder(recorder))
        #expect(window.firstResponder === recorder)
        #expect(recorder.focusRingType == .exterior)
        #expect(recorder.accessibilityValue() as? String == "Unassigned")
        #expect(recording == 0 && assignments == 0 && !recorder.isRecording)
        #expect(!window.isVisible)
    }
    private final class Document: NSView {
        override var isFlipped: Bool { true }
    }

    private func fixture() -> (NSWindow, NSScrollView, [PracticeShortcutTarget: NSControl]) {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 240),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 240))
        let document = Document(frame: NSRect(x: 0, y: 0, width: 400, height: 2000))
        scroll.documentView = document
        window.contentView = scroll
        var controls: [PracticeShortcutTarget: NSControl] = [:]
        for (index, target) in PracticeShortcutTarget.allCases.enumerated() {
            let control: NSControl = target == .radial ? ShortcutModifierPicker.Button()
                : ShortcutRecorder(shortcut: nil, command: target.rawValue)
            control.frame = NSRect(x: 40, y: 400 + index * 400, width: 160, height: 32)
            document.addSubview(control)
            controls[target] = control
        }
        window.contentView?.layoutSubtreeIfNeeded()
        return (window, scroll, controls)
    }

    @Test func allMountedDestinationsScrollAndFocusWithoutRecordingOrAssignment() throws {
        let (window, scroll, controls) = fixture()
        let model = SettingsModel()
        let navigation = ShortcutNavigation()
        let saved = Preferences.shortcutState
        let radial = Preferences.radialTrigger
        var recording = 0
        var assignments = 0
        for control in controls.values {
            if let recorder = control as? ShortcutRecorder {
                recorder.onRecording = { _ in recording += 1 }
                recorder.onChange = { _ in assignments += 1; return true }
            }
            if let popup = control as? ShortcutModifierPicker.Button { popup.onSelection = { _ in assignments += 1 } }
        }
        for target in PracticeShortcutTarget.allCases {
            let control = try #require(controls[target])
            #expect(control.accessibilityIdentifier() == target.controlIdentifier)
            #expect(ShortcutNavigation.control(for: target, in: scroll) === control)
            model.focusShortcut(target)
            #expect(navigation.resolve(in: scroll, model: model, canFocus: true))
            #expect(window.firstResponder === control)
            #expect(scroll.documentVisibleRect.contains(control.frame))
            #expect((control as? ShortcutRecorder)?.isRecording != true)
        }
        #expect(recording == 0 && assignments == 0)
        #expect(NSDictionary(dictionary: Preferences.shortcutState).isEqual(to: saved))
        #expect(Preferences.radialTrigger == radial)
        #expect(!window.isVisible)
    }

    @Test func repeatedLinksUseNewIdentityAndResizeOnlyRevealsTheStillFocusedDestination() throws {
        let (window, scroll, controls) = fixture()
        let model = SettingsModel()
        let navigation = ShortcutNavigation()
        let pen = try #require(controls[.drawing])
        let pointer = try #require(controls[.pointer])
        model.focusShortcut(.drawing)
        #expect(navigation.resolve(in: scroll, model: model, canFocus: true))
        let first = navigation.completedRequestID
        window.makeFirstResponder(pointer)
        #expect(!navigation.resolve(in: scroll, model: model, canFocus: true, revealFocused: true))
        #expect(window.firstResponder === pointer)
        model.focusShortcut(.drawing)
        #expect(navigation.resolve(in: scroll, model: model, canFocus: true))
        #expect(navigation.completedRequestID != first)
        #expect(window.firstResponder === pen)
        window.setContentSize(NSSize(width: 400, height: 120))
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        #expect(!scroll.documentVisibleRect.contains(pen.frame))
        #expect(!navigation.resolve(in: scroll, model: model, canFocus: true, revealFocused: true))
        #expect(scroll.documentVisibleRect.contains(pen.frame))
        #expect(window.firstResponder === pen)
        // A layout after manual scrolling must not pull the viewport back.
        scroll.contentView.scroll(to: .zero)
        let manuallyScrolled = scroll.documentVisibleRect
        #expect(!navigation.resolve(in: scroll, model: model, canFocus: true))
        #expect(scroll.documentVisibleRect == manuallyScrolled)
    }

    @Test func cancelledSupersededAndInactiveRequestsCannotStealFocus() throws {
        let (window, scroll, controls) = fixture()
        let model = SettingsModel()
        let navigation = ShortcutNavigation()
        let pointer = try #require(controls[.pointer])
        window.makeFirstResponder(pointer)
        model.focusShortcut(.drawing)
        #expect(!navigation.resolve(in: scroll, model: model, canFocus: false))
        #expect(window.firstResponder === pointer)
        model.section = .general
        #expect(model.shortcutFocusRequest == nil)
        model.section = .shortcuts
        #expect(!navigation.resolve(in: scroll, model: model, canFocus: true))
        model.focusShortcut(.drawing)
        model.cancelShortcutNavigation()
        #expect(!navigation.resolve(in: scroll, model: model, canFocus: true))
        #expect(window.firstResponder === pointer)
        model.focusShortcut(.drawing)
        model.focusShortcut(.interact)
        #expect(navigation.resolve(in: scroll, model: model, canFocus: true))
        #expect(window.firstResponder === controls[.interact])
    }

    @Test func realShortcutsPageMountsAllFourNativeDestinations() throws {
        _ = NSApplication.shared
        let model = SettingsModel()
        let host = SettingsHostingView(model: model)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 784, height: 440),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let navigation = ShortcutNavigation()
        #expect(ShortcutNavigation.control(for: .drawing, in: host) == nil)
        for height in [640, 440, 520] {
            window.setContentSize(NSSize(width: 784, height: height))
            // Rebuild the Shortcuts content after leaving it, as the practice link does.
            model.section = .general
            host.layoutSubtreeIfNeeded()
            for target in [PracticeShortcutTarget.drawing, .interact, .pointer, .radial, .drawing] {
                model.focusShortcut(target)
                host.layoutSubtreeIfNeeded()
                let control = try #require(ShortcutNavigation.control(for: target, in: host))
                #expect(navigation.resolve(in: host, model: model, canFocus: true))
                #expect(window.firstResponder === control)
                #expect(control.visibleRect.contains(control.bounds))
                #expect((control as? ShortcutRecorder)?.isRecording != true)
            }
        }
        #expect(!window.isVisible)
    }

    @Test func unmountedDestinationWaitsForLayoutWithoutConsumingRequest() throws {
        let (window, scroll, controls) = fixture()
        let pen = try #require(controls[.drawing])
        let document = try #require(pen.superview)
        pen.removeFromSuperview()
        let model = SettingsModel()
        let navigation = ShortcutNavigation()
        model.focusShortcut(.drawing)
        #expect(!navigation.resolve(in: scroll, model: model, canFocus: true))
        #expect(navigation.completedRequestID == nil)
        document.addSubview(pen)
        document.layoutSubtreeIfNeeded()
        #expect(navigation.resolve(in: scroll, model: model, canFocus: true))
        #expect(window.firstResponder === pen)
        #expect(scroll.documentVisibleRect.contains(pen.frame))
    }
}
