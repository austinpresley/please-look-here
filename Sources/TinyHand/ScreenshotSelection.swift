import AppKit

enum ScreenshotRegion {
    /// AppKit display coordinates become top-left image pixels, including Retina scale.
    static func pixels(for region: CGRect, on display: CGRect, imageSize: CGSize) -> CGRect? {
        let area = region.standardized.intersection(display)
        guard !area.isNull, area.width >= 2, area.height >= 2,
              display.width > 0, display.height > 0, imageSize.width > 0, imageSize.height > 0 else { return nil }
        let sx = imageSize.width / display.width, sy = imageSize.height / display.height
        let x = floor((area.minX - display.minX) * sx)
        let y = floor((display.maxY - area.maxY) * sy)
        let right = ceil((area.maxX - display.minX) * sx)
        let bottom = ceil((display.maxY - area.minY) * sy)
        return CGRect(x: x, y: y, width: right - x, height: bottom - y)
            .intersection(CGRect(origin: .zero, size: imageSize))
    }
}

/// A local, app-owned selection window. Screen capture excludes it automatically.
final class ScreenshotSelection {
    private final class SelectionPanel: NSPanel {
        var canceled: (() -> Void)?
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
        override func cancelOperation(_ sender: Any?) { canceled?() }
    }

    private final class SelectionView: NSView {
        var completed: ((CGRect) -> Void)?
        var canceled: (() -> Void)?
        private var start: CGPoint?
        private var end: CGPoint?
        override var acceptsFirstResponder: Bool { true }
        override func cancelOperation(_ sender: Any?) { canceled?() }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
        override func mouseDown(with event: NSEvent) {
            start = convert(event.locationInWindow, from: nil)
            end = start
            needsDisplay = true
        }
        override func mouseDragged(with event: NSEvent) {
            end = convert(event.locationInWindow, from: nil)
            needsDisplay = true
        }
        override func mouseUp(with event: NSEvent) {
            guard let start else { return }
            let end = convert(event.locationInWindow, from: nil)
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                              width: abs(start.x - end.x), height: abs(start.y - end.y))
            if rect.width < 2 || rect.height < 2 { canceled?() }
            else { completed?(rect.intersection(bounds)) }
        }
        override func draw(_ dirtyRect: NSRect) {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            NSColor.black.withAlphaComponent(0.3).setFill()
            bounds.fill()
            if let start, let end {
                let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                                  width: abs(start.x - end.x), height: abs(start.y - end.y))
                context.clear(rect)
                NSColor.white.setStroke()
                let outline = NSBezierPath(rect: rect)
                outline.lineWidth = 2
                outline.stroke()
            }
            let instructions = "Drag to capture a region. Press Escape to cancel."
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium),
                                                           .foregroundColor: NSColor.white]
            let size = instructions.size(withAttributes: attributes)
            let box = CGRect(x: (bounds.width - size.width) / 2 - 16,
                             y: bounds.height - 64, width: size.width + 32, height: 40)
            NSColor.black.withAlphaComponent(0.8).setFill()
            NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8).fill()
            instructions.draw(at: CGPoint(x: box.minX + 16, y: box.minY + 12), withAttributes: attributes)
        }
    }

    private var panel: SelectionPanel?
    private var completion: ((CGRect?) -> Void)?
    var isVisible: Bool { panel?.isVisible == true }

    func show(on screen: NSScreen, completion: @escaping (CGRect?) -> Void) {
        cancel()
        self.completion = completion
        let panel = SelectionPanel(contentRect: screen.frame, styleMask: .borderless,
                                   backing: .buffered, defer: false)
        panel.title = "Capture region"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 6)
        panel.collectionBehavior = [.fullScreenAuxiliary]
        let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.setAccessibilityLabel("Drag to select a screenshot region. Press Escape to cancel.")
        view.completed = { [weak self] rect in
            self?.finish(CGRect(x: rect.minX + screen.frame.minX, y: rect.minY + screen.frame.minY,
                               width: rect.width, height: rect.height))
        }
        view.canceled = { [weak self] in self?.cancel() }
        panel.canceled = { [weak self] in self?.cancel() }
        panel.contentView = view
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(view)
    }

    func cancel() { finish(nil) }

    private func finish(_ rect: CGRect?) {
        let callback = completion
        completion = nil
        panel?.orderOut(nil)
        panel = nil
        callback?(rect)
    }
}
