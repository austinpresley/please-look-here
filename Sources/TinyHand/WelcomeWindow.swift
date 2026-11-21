import AppKit
import ApplicationServices

final class WelcomeWindow: NSObject {
    var onTryIt: ((PointerMode) -> Void)?
    var onSetKey: (() -> Void)?
    private let keyButton = NSButton()
    private let practiceLink = NSButton()
    var onPractice: (() -> Void)?
    private var forDrawing = false
    var simulateUntrusted = false
    var accessibility: () -> Bool = { AXIsProcessTrusted() }
    var primaryButton: NSButton { button }

    private final class Card: NSWindow {
        override var canBecomeKey: Bool { true }
        override func cancelOperation(_ sender: Any?) {
            orderOut(nil)
        }
    }

    var nativeWindow: NSWindow? { window }
    private var window: Card?
    private var timer: Timer?
    private var askedAt: Date?
    private let title = NSTextField(labelWithString: "")
    private let subtitle = NSTextField(labelWithString: "")
    private let button = NSButton(title: "", target: nil, action: nil)
    private let tip = NSTextField(labelWithString: "Already on? Remove it and add it again.")

    static let shownKey = "welcomeShown"

    func show(forDrawing: Bool = false) {
        self.forDrawing = forDrawing
        if window == nil {
            build()
        }
        refresh()
        Preferences.storage.set(true, forKey: WelcomeWindow.shownKey)
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.invalidateShadow()
        window?.makeFirstResponder(nil)
        timer?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private var granted: Bool {
        accessibility() && !simulateUntrusted
    }

    private func refresh() {
        title.isHidden = !forDrawing
        title.stringValue = forDrawing ? (granted ? "Drawing is ready" : "Allow drawing") : "Look Here Please"
        subtitle.stringValue = forDrawing ? "Choose a drawing tool to draw on screen.\nCursor works without permission." : ""
        subtitle.isHidden = !forDrawing
        keyButton.title = Preferences.radialTrigger.map(\.holdInstruction) ?? "Set key"
        keyButton.setAccessibilityLabel(Preferences.radialTrigger.map(\.holdHelp) ?? "Set key for Quick controls")
        keyButton.toolTip = Preferences.radialTrigger.map { $0.holdHelp + " Change key in Shortcuts." } ?? "Choose the held key for Quick controls in Shortcuts."
        let linkColor = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? ControlPalette.foreground(NSApp.effectiveAppearance) : ControlPalette.accent(NSApp.effectiveAppearance)
        practiceLink.attributedTitle = NSAttributedString(string: "Practice", attributes: [.foregroundColor: linkColor, .font: NSFont.systemFont(ofSize: 13)])
        button.bezelColor = ControlPalette.accent(NSApp.effectiveAppearance)
        button.title = forDrawing ? (granted ? "Start Drawing" : "Open Settings") : "Show Pointer"
        button.setAccessibilityLabel(button.title)
        tip.isHidden = !forDrawing || granted || askedAt.map { Date().timeIntervalSince($0) < 10 } ?? true
    }

    @objc private func buttonPressed() {
        if !forDrawing || granted {
            close()
            onTryIt?(forDrawing ? .draw : .point)
            return
        }
        askedAt = Date()
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func close() {
        timer?.invalidate()
        timer = nil
        window?.orderOut(nil)
    }

    @objc private func setKeyPressed() { close(); onSetKey?() }

    @objc private func practicePressed() {
        close()
        onPractice?()
    }

    private func build() {
        let size = CGSize(width: 340, height: 380)
        let w = Card(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        w.title = "Look Here Please"
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.level = .normal

        let card = NSVisualEffectView(frame: CGRect(origin: .zero, size: size))
        card.material = .popover
        card.blendingMode = .behindWindow
        card.state = .active
        card.roundCorners(20)
        w.contentView = card

        let icon = NSImageView()
        icon.image = Toolbar.icon(for: PointerStyle.saved)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 76).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 76).isActive = true

        title.font = NSFont.systemFont(ofSize: 19, weight: .semibold)
        title.alignment = .center
        subtitle.font = NSFont.systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.maximumNumberOfLines = 3
        subtitle.preferredMaxLayoutWidth = 296
        subtitle.widthAnchor.constraint(equalToConstant: 296).isActive = true

        button.target = self
        button.action = #selector(buttonPressed)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.keyEquivalent = "\r"

        tip.font = NSFont.systemFont(ofSize: 11)
        tip.textColor = .secondaryLabelColor
        tip.alignment = .center

        let practice = practiceLink
        practice.title = "Practice"; practice.target = self; practice.action = #selector(practicePressed)
        practice.bezelStyle = .rounded
        practice.isBordered = false
        practice.contentTintColor = ControlPalette.accent(NSApp.effectiveAppearance)
        practice.toolTip = "Practice Cursor, drawing and Quick controls locally. No permission is needed."
        let tiles = NSStackView(); tiles.orientation = .horizontal; tiles.spacing = 8
        for (name, symbol) in [("Click", "cursorarrow.click"), ("Draw", "pencil.tip"), ("Quick controls", "circle.grid.2x2")] {
            let picture = WelcomePicture(kind: name)
            picture.setAccessibilityLabel(name)
            picture.widthAnchor.constraint(equalToConstant: 80).isActive = true
            picture.heightAnchor.constraint(equalToConstant: 48).isActive = true
            let label: NSView
            if name == "Quick controls" {
                keyButton.target = self; keyButton.action = #selector(setKeyPressed); keyButton.bezelStyle = .rounded; label = keyButton
            } else { label = NSTextField(labelWithString: name) }
            let tile = NSStackView(views: [picture, label]); tile.orientation = .vertical; tile.spacing = 8
            tile.edgeInsets = NSEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
            tile.wantsLayer = true; tile.layer?.cornerRadius = 12
            tile.setAccessibilityLabel(name); tile.toolTip = name == "Click" ? "Cursor sends clicks through to apps" : name == "Draw" ? "Choose a drawing tool to draw" : "Hold, move, release to choose"
            _ = symbol
            tiles.addArrangedSubview(tile)
        }
        title.isHidden = true
        button.widthAnchor.constraint(equalToConstant: 280).isActive = true
        let stack = NSStackView(views: [icon, title, subtitle, tiles, button, practice, tip])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setCustomSpacing(16, after: icon)
        stack.setCustomSpacing(16, after: tiles)
        stack.setCustomSpacing(12, after: button)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let closeButton = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")!,
                                   target: self, action: #selector(close))
        closeButton.isBordered = false
        closeButton.contentTintColor = .tertiaryLabelColor
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(closeButton)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: 4),
            closeButton.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            closeButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])
        card.removeFocusRings()
        window = w
    }

    func snapshot() -> NSBitmapImageRep? {
        if window == nil {
            build()
        }
        if simulateUntrusted {
            askedAt = Date().addingTimeInterval(-20)
        }
        refresh()
        guard let view = window?.contentView else {
            return nil
        }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return nil
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }
}

/// Small illustrations explain the actions without requesting desktop input.
private final class WelcomePicture: NSView {
    let kind: String
    init(kind: String) { self.kind = kind; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    override func draw(_ dirtyRect: NSRect) {
        let frame = bounds.insetBy(dx: 12, dy: 8)
        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
        let outline = NSBezierPath(roundedRect: frame, xRadius: 4, yRadius: 4); outline.lineWidth = 1; outline.stroke()
        if kind == "Draw" {
            ControlPalette.accent(effectiveAppearance).setStroke()
            let line = NSBezierPath(); line.move(to: CGPoint(x: 18, y: 16)); line.curve(to: CGPoint(x: 64, y: 28), controlPoint1: CGPoint(x: 32, y: 48), controlPoint2: CGPoint(x: 44, y: 0)); line.lineWidth = 3; line.stroke()
        } else {
            let symbol = "cursorarrow"
            var tint = NSColor.labelColor
            effectiveAppearance.performAsCurrentDrawingAppearance { tint = NSColor.labelColor.usingColorSpace(.deviceRGB) ?? .labelColor }
            let image = NSImage(size: CGSize(width: 24, height: 24), flipped: false) { rect in
                (self.kind == "Click" ? NSImage(systemSymbolName: symbol, accessibilityDescription: nil) : UsabilityGlyph.wheel.image)?.draw(in: rect)
                tint.setFill(); rect.fill(using: .sourceAtop)
                return true
            }
            image.draw(in: CGRect(x: 28, y: 12, width: 24, height: 24))
        }
    }
}
