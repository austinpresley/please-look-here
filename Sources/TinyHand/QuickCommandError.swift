import AppKit

enum QuickCommandRecovery: Equatable {
    case settings, accessibility, screenRecording, captureFolder, retryScreenshot
    var title: String {
        switch self {
        case .settings: return "Open Settings"
        case .accessibility: return "Open Accessibility Settings"
        case .screenRecording: return "Open Screen Recording Settings"
        case .captureFolder: return "Choose Folder…"
        case .retryScreenshot: return "Retry Screenshot"
        }
    }
}

struct QuickCommandFailure: Equatable {
    let title: String
    let reason: String
    let recovery: QuickCommandRecovery
    static func rejected(operation: String, code: String, reason: String) -> Self {
        let recovery: QuickCommandRecovery = code == "accessibility" ? .accessibility : code == "screen-recording" ? .screenRecording : .settings
        let title = operation == "capture" ? "Couldn't take screenshot" : "Couldn't apply Quick controls command"
        return Self(title: title, reason: reason, recovery: recovery)
    }
    static func capture(_ error: Error) -> Self {
        let folder = (error as NSError).domain == NSCocoaErrorDomain && !(error is ScreenshotError)
        return Self(title: folder ? "Couldn't save screenshot" : "Couldn't take screenshot", reason: error.localizedDescription,
                    recovery: folder ? .captureFolder : ScreenshotRecovery.action(for: error) == .permissionSettings ? .screenRecording : .retryScreenshot)
    }
}

enum QuickCommandResult: Equatable {
    case success, failure(QuickCommandFailure)
    static func bridge(_ response: [String: Any], operation: String) -> Self {
        if response["ok"] as? Bool == true { return .success }
        let error = response["error"] as? [String: Any] ?? [:]
        return .failure(.rejected(operation: operation, code: error["code"] as? String ?? "unavailable", reason: error["message"] as? String ?? "The command is unavailable. Check Settings and try again."))
    }
    var message: String { if case .failure(let error) = self { return error.reason }; return "Selected" }
}

struct QuickCommandErrorState {
    private(set) var failure: QuickCommandFailure?
    /// Repeated refreshes of a visible error never repeat its announcement.
    mutating func present(_ failure: QuickCommandFailure) -> Bool {
        let changed = self.failure != failure; self.failure = failure; return changed
    }
    mutating func dismiss() { failure = nil }
}

/// Persistent and nonactivating. Recovery and dismissal are explicit actions;
/// showing a failure never changes the current key window or responder.
final class QuickCommandError: NSObject, NSWindowDelegate {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
        var onDismiss: (() -> Void)?
        override func cancelOperation(_ sender: Any?) { onDismiss?() }
    }
    let window: NSPanel
    private let surface = QuickRecoverySurface(cornerRadius: 12)
    private let title = NSTextField(wrappingLabelWithString: "")
    private let reason = NSTextField(wrappingLabelWithString: "")
    private let recovery = QuickRecoveryButton(title: "Open Settings", target: nil, action: nil)
    private let dismissButton = QuickRecoveryButton(title: "✕", target: nil, action: nil)
    private(set) var state = QuickCommandErrorState()
    var onRecover: ((QuickCommandRecovery) -> Void)?
    var diagnostics: [String: Any] { ["visible": window.isVisible, "keyWindow": window.isKeyWindow, "title": title.stringValue, "reason": reason.stringValue, "action": recovery.title, "accessibilityHidden": window.contentView?.isAccessibilityHidden() ?? true, "recoveryHeight": recovery.frame.height, "dismissSize": [dismissButton.frame.width, dismissButton.frame.height], "dismissLabel": dismissButton.accessibilityLabel() ?? "", "cornerRadius": surface.cornerRadius, "recoveryFocused": window.firstResponder === recovery, "dismissFocused": window.firstResponder === dismissButton] }
    override init() {
        let panel = Panel(contentRect: CGRect(x: 0, y: 0, width: 480, height: 160), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window = panel
        super.init()
        panel.title = "Quick controls error"; panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false; panel.becomesKeyOnlyIfNeeded = true
        panel.delegate = self
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 4)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.onDismiss = { [weak self] in self?.dismiss() }
        let content = NSView(); content.wantsLayer = true; content.addSubview(surface); panel.contentView = content
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = NSColor(name: nil) { RadialAppearance.color(RadialAppearance.system($0).text) }
        reason.font = .systemFont(ofSize: 12)
        reason.textColor = NSColor(name: nil) { RadialAppearance.color(RadialAppearance.system($0).secondary) }
        recovery.prominent = true; recovery.isBordered = false; recovery.target = self; recovery.action = #selector(recover)
        dismissButton.isBordered = false; dismissButton.target = self; dismissButton.action = #selector(dismiss)
        dismissButton.setAccessibilityLabel("Dismiss")
        recovery.focusRingType = .none; dismissButton.focusRingType = .none
        recovery.nextKeyView = dismissButton; dismissButton.nextKeyView = recovery
        recovery.toolTip = "Resolve this command failure"; dismissButton.toolTip = "Dismiss this error"
        [title, reason, recovery, dismissButton].forEach { surface.addSubview($0) }
        content.setAccessibilityHidden(true)
    }
    func windowDidBecomeKey(_ notification: Notification) { recovery.needsDisplay = true; dismissButton.needsDisplay = true }
    func windowDidResignKey(_ notification: Notification) { recovery.needsDisplay = true; dismissButton.needsDisplay = true }
    func show(_ failure: QuickCommandFailure, on bounds: CGRect? = nil) {
        let announce = state.present(failure)
        title.stringValue = failure.title; reason.stringValue = failure.reason; reason.toolTip = failure.reason; recovery.title = failure.recovery.title
        recovery.setAccessibilityLabel(failure.recovery.title)
        let width: CGFloat = 448
        func height(_ text: String, font: NSFont) -> CGFloat {
            let measured = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font]).height
            return max(20, ceil(measured / 4) * 4)
        }
        let titleHeight = height(failure.title, font: title.font!), reasonHeight = height(failure.reason, font: reason.font!)
        let panelHeight = 16 + titleHeight + 8 + reasonHeight + 12 + 28 + 16
        // The same 12-point shadow insets as Clear keep the shared material's
        // shadow inside the window without changing the card's 480-point width.
        window.setContentSize(CGSize(width: 504, height: panelHeight + 24))
        surface.frame = CGRect(x: 12, y: 12, width: 480, height: panelHeight)
        title.frame = CGRect(x: 16, y: panelHeight - 16 - titleHeight, width: width, height: titleHeight)
        reason.frame = CGRect(x: 16, y: 56, width: width, height: reasonHeight)
        let actionWidth = (recovery.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold)]).width
        recovery.frame = CGRect(x: 16, y: 16, width: max(120, ceil((actionWidth + 24) / 4) * 4), height: 28)
        dismissButton.frame = CGRect(x: 436, y: 16, width: 28, height: 28)
        let bounds = bounds ?? NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1200, height: 800)
        window.setFrameOrigin(CGPoint(x: bounds.midX - window.frame.width / 2, y: bounds.minY + 84))
        window.contentView?.setAccessibilityHidden(false); window.orderFrontRegardless()
        if announce {
            NSAccessibility.post(element: title, notification: .announcementRequested, userInfo: [.announcement: failure.title + ". " + failure.reason + ". " + failure.recovery.title, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
    }
    /// Called only by the disposable test control bridge, without native input.
    func verifyFocus(dismiss: Bool) {
        guard window.isVisible else { return }
        window.makeKeyAndOrderFront(nil); window.makeFirstResponder(dismiss ? dismissButton : recovery)
    }
    @objc func dismiss() { state.dismiss(); window.contentView?.setAccessibilityHidden(true); window.orderOut(nil) }
    @objc private func recover() { guard let failure = state.failure else { return }; dismiss(); onRecover?(failure.recovery) }
}
