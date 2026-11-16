import AppKit

enum ScreenshotRecovery: Equatable {
    case permissionSettings, retry

    static func action(for error: Error) -> ScreenshotRecovery {
        if let failure = error as? ScreenshotError, case .permission = failure {
            return .permissionSettings
        }
        return .retry
    }

    var title: String {
        self == .permissionSettings ? "Open Screen Recording Settings" : "Retry"
    }
}

/// Keeps only the latest capture. Its actions never take another screenshot.
final class ScreenshotResult: NSObject {
    private final class ResultPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
        override func cancelOperation(_ sender: Any?) { orderOut(nil) }
    }

    private var panel: ResultPanel?
    private var png: Data?
    private var destination: URL?
    private let title = NSTextField(labelWithString: "Screenshot ready")
    private let detail = NSTextField(labelWithString: "")
    private let reveal = NSButton(title: "Reveal in Finder", target: nil, action: nil)
    private let copy = NSButton(title: "Copy", target: nil, action: nil)
    var window: NSWindow? { panel }

    func show(png: Data, destination: URL?, copied: Bool, on screen: NSScreen?) {
        if panel == nil { build() }
        self.png = png
        self.destination = destination
        title.stringValue = destination == nil ? "Screenshot copied to clipboard" : "Screenshot saved"
        detail.stringValue = destination?.lastPathComponent ?? "Copy it again whenever you need it."
        detail.toolTip = destination?.path
        reveal.isHidden = destination == nil
        reveal.isEnabled = destination != nil
        copy.title = copied ? "Copy Again" : "Copy"
        guard let panel else { return }
        let bounds = (screen ?? NSScreen.main)?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1200, height: 800)
        panel.setFrameOrigin(CGPoint(x: bounds.maxX - panel.frame.width - 20,
                                     y: bounds.maxY - panel.frame.height - 20))
        panel.orderFrontRegardless()
        let environment = ProcessInfo.processInfo.environment
        if environment["TINYHAND_TEST_MODE"] == "1" && environment["TH_FOCUS_CAPTURE_RESULT"] == "1" {
            panel.makeKeyAndOrderFront(nil)
        }
        panel.makeFirstResponder(nil)
        NSAccessibility.post(element: title, notification: .announcementRequested,
                             userInfo: [.announcement: title.stringValue,
                                        .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }

    func close() { panel?.orderOut(nil) }

    private func build() {
        let panel = ResultPanel(contentRect: CGRect(x: 0, y: 0, width: 420, height: 132),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Screenshot result"
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 4)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let surface = NSVisualEffectView()
        surface.material = .popover
        surface.blendingMode = .behindWindow
        surface.state = .active
        surface.wantsLayer = true
        surface.layer?.cornerRadius = 12
        panel.contentView = surface
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingMiddle
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        reveal.target = self; reveal.action = #selector(revealFile)
        reveal.bezelStyle = .rounded
        reveal.toolTip = "Select the saved screenshot in Finder"
        copy.target = self; copy.action = #selector(copyImage)
        copy.bezelStyle = .rounded
        copy.toolTip = "Copy this screenshot to the clipboard"
        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Screenshot Result")!, target: self, action: #selector(dismiss))
        close.isBordered = false
        close.toolTip = "Close screenshot result"
        let heading = NSStackView(views: [title, NSView(), close])
        heading.orientation = .horizontal
        heading.alignment = .centerY
        heading.spacing = 8
        let buttons = NSStackView(views: [reveal, copy, NSView()])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        let root = NSStackView(views: [heading, detail, buttons])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: surface.topAnchor, constant: 16),
            root.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -16),
            heading.widthAnchor.constraint(equalTo: root.widthAnchor),
            detail.widthAnchor.constraint(equalTo: root.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
        self.panel = panel
    }

    @objc private func revealFile() {
        guard let destination else { return }
        guard FileManager.default.fileExists(atPath: destination.path) else {
            detail.stringValue = "The saved file was moved or removed. You can still copy it."
            reveal.isEnabled = false
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([destination])
    }

    @objc private func copyImage() {
        guard let png else { return }
        detail.stringValue = ScreenCapture.copy(png) ? "Copied to clipboard" : "Couldn't copy the image. Try again."
    }

    @objc private func dismiss() { close() }
}
