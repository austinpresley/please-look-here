import AppKit

final class TextAnnotationEditor: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    private var panel: NSPanel?
    private let field = NSTextField(string: "")
    private var completion: ((String?) -> Void)?
    var isShowing: Bool { panel?.isVisible == true }

    func show(at point: CGPoint, completion: @escaping (String?) -> Void) {
        cancel()
        self.completion = completion
        let p = NSPanel(contentRect: CGRect(x: point.x, y: point.y - 120, width: 360, height: 120),
                        styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
        p.title = "Add Text"
        p.isReleasedWhenClosed = false
        p.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 5)
        p.delegate = self
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        p.contentView?.addSubview(stack)
        if let content = p.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                stack.topAnchor.constraint(equalTo: content.topAnchor), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor)
            ])
        }
        field.stringValue = ""
        field.placeholderString = "Type a label"
        field.delegate = self
        field.setAccessibilityLabel("Annotation text")
        field.widthAnchor.constraint(equalToConstant: 320).isActive = true
        stack.addArrangedSubview(field)
        let buttons = NSStackView()
        buttons.orientation = .horizontal; buttons.spacing = 8
        buttons.addArrangedSubview(NSButton(title: "Cancel", target: self, action: #selector(cancelAction)))
        let add = NSButton(title: "Add Text", target: self, action: #selector(addAction))
        add.keyEquivalent = "\r"
        buttons.addArrangedSubview(add)
        stack.addArrangedSubview(buttons)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            let area = screen.visibleFrame.insetBy(dx: 8, dy: 8)
            p.setFrameOrigin(CGPoint(x: min(max(point.x, area.minX), area.maxX - p.frame.width),
                                     y: min(max(point.y - p.frame.height, area.minY), area.maxY - p.frame.height)))
        }
        panel = p
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
        p.makeFirstResponder(field)
    }
    @objc private func addAction() {
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { NSSound.beep(); return }
        finish(text)
    }
    @objc private func cancelAction() { cancel() }
    func cancel() { finish(nil) }
    private func finish(_ text: String?) {
        let callback = completion
        completion = nil
        panel?.orderOut(nil)
        panel = nil
        callback?(text)
    }
    func windowWillClose(_ notification: Notification) { cancel() }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) { addAction(); return true }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { cancel(); return true }
        return false
    }
}
