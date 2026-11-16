import AppKit
import SwiftUI

/// Resolves only mounted native controls, after the hosting view has laid out.
/// Becoming first responder never sends a control's action.
final class ShortcutNavigation {
    private(set) var completedRequestID: UUID?

    @discardableResult
    func resolve(in root: NSView, model: SettingsModel, canFocus: Bool, revealFocused: Bool = false) -> Bool {
        guard canFocus, model.section == .shortcuts, let request = model.shortcutFocusRequest,
              let window = root.window,
              let control = Self.control(for: request.target, in: root),
              !control.isHiddenOrHasHiddenAncestor, control.isEnabled,
              control.bounds.width > 0, control.bounds.height > 0 else { return false }
        if completedRequestID == request.id {
            // A resize can clip the focused command after automatic Settings sizing.
            // Do not undo a person's scrolling or move focus back from another control.
            if revealFocused, window.firstResponder === control { reveal(control) }
            return false
        }
        reveal(control)
        guard model.shortcutFocusRequest == request, model.section == .shortcuts,
              window.makeFirstResponder(control) else { return false }
        completedRequestID = request.id
        return true
    }

    private func reveal(_ control: NSControl) {
        control.scrollToVisible(control.bounds.insetBy(dx: -8, dy: -12))
    }

    static func control(for target: PracticeShortcutTarget, in root: NSView) -> NSControl? {
        if let control = root as? NSControl, control.identifier?.rawValue == target.controlIdentifier {
            return control
        }
        for child in root.subviews {
            if let control = control(for: target, in: child) { return control }
        }
        return nil
    }
}

final class SettingsHostingView: NSHostingView<SettingsView> {
    private let model: SettingsModel
    private let navigation = ShortcutNavigation()
    private var navigationScheduled = false
    private var revealFocused = false

    convenience init(model: SettingsModel) {
        self.init(rootView: SettingsView(model: model))
    }

    required init(rootView: SettingsView) {
        self.model = rootView.model
        super.init(rootView: rootView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func layout() {
        super.layout()
        scheduleShortcutNavigation()
    }

    func scheduleShortcutNavigation(revealFocused: Bool = false) {
        guard model.shortcutFocusRequest != nil else { return }
        self.revealFocused = self.revealFocused || revealFocused
        guard !navigationScheduled else { return }
        navigationScheduled = true
        // One handoff from SwiftUI update/layout to completed AppKit layout, not
        // a timed retry. Mounting or resizing supplies any later layout signal.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            defer { self.navigationScheduled = false; self.revealFocused = false }
            guard self.model.shortcutFocusRequest != nil, self.model.section == .shortcuts,
                  let window = self.window, window.isKeyWindow, NSApp.isActive else { return }
            self.layoutSubtreeIfNeeded()
            self.navigation.resolve(in: self, model: self.model, canFocus: window.isKeyWindow && NSApp.isActive,
                                    revealFocused: self.revealFocused)
        }
    }
}

/// A native popup gives the radial destination the same stable identity and
/// inactive focus as the recorder buttons. Selection still requires activation.
struct ShortcutModifierPicker: NSViewRepresentable {
    @Binding var selection: String

    final class Button: NSPopUpButton {
        var onSelection: ((String) -> Void)?
        override var acceptsFirstResponder: Bool { true }

        init() {
            super.init(frame: .zero, pullsDown: false)
            identifier = NSUserInterfaceItemIdentifier(PracticeShortcutTarget.radial.controlIdentifier)
            setAccessibilityIdentifier(PracticeShortcutTarget.radial.controlIdentifier)
            setAccessibilityLabel("Radial menu modifier")
            addItem(withTitle: "Unassigned")
            lastItem?.representedObject = ""
            for trigger in RadialTrigger.allCases {
                addItem(withTitle: trigger.title)
                lastItem?.representedObject = trigger.rawValue
            }
            target = self
            action = #selector(selectModifier)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

        @objc private func selectModifier() {
            guard let value = selectedItem?.representedObject as? String else { return }
            onSelection?(value)
        }
    }

    func makeNSView(context: Context) -> Button {
        let button = Button()
        button.onSelection = { selection = $0 }
        return button
    }

    func updateNSView(_ button: Button, context: Context) {
        button.onSelection = { selection = $0 }
        button.selectItem(at: button.itemArray.firstIndex { $0.representedObject as? String == selection } ?? 0)
    }
}
