import AppKit

final class FixtureWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class FixtureCanvas: NSView {
    let counter = NSTextField(labelWithString: "Button clicks: 0 · Canvas down: 0 · Canvas up: 0 · Drags: 0")
    private var buttonClicks = 0, downs = 0, ups = 0, drags = 0
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); dirtyRect.fill()
        if ProcessInfo.processInfo.environment["TINYHAND_FIXTURE_MAGNIFIER"] == "1" {
            let path = NSBezierPath()
            for x in stride(from: CGFloat(240), through: bounds.width - 80, by: 40) {
                path.move(to: CGPoint(x: x, y: 280)); path.line(to: CGPoint(x: x, y: bounds.height - 80))
            }
            for y in stride(from: CGFloat(280), through: bounds.height - 80, by: 40) {
                path.move(to: CGPoint(x: 240, y: y)); path.line(to: CGPoint(x: bounds.width - 80, y: y))
            }
            NSColor.lightGray.setStroke(); path.lineWidth = 1; path.stroke()
            let text = "Magnifier fixture: small text, 0123456789, upright ABC" as NSString
            text.draw(at: CGPoint(x: 320, y: 380), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), .foregroundColor: NSColor.black])
            NSColor.systemRed.setFill(); CGRect(x: 480, y: 440, width: 16, height: 16).fill()
            NSColor.systemBlue.setFill(); CGRect(x: 520, y: 440, width: 16, height: 16).fill()
        }
    }
    override func mouseDown(with event: NSEvent) { downs += 1; refresh() }
    override func mouseUp(with event: NSEvent) { ups += 1; refresh() }
    override func mouseDragged(with event: NSEvent) { drags += 1; refresh() }
    @objc func clickTarget() { buttonClicks += 1; refresh() }
    @objc func contextAction() { buttonClicks += 10; refresh() }
    private func refresh() { counter.stringValue = "Button clicks: \(buttonClicks) · Canvas down: \(downs) · Canvas up: \(ups) · Drags: \(drags)" }
}

final class FixtureDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var eventCounts: [String: Int] = [:]
    private var lastFlags: [String: UInt] = [:]
    private var monitor: Any?
    private func writeProbeState() {
        guard let path = ProcessInfo.processInfo.environment["TINYHAND_FIXTURE_STATE"], path.hasPrefix("/tmp/s013-") else { return }
        let state: [String: Any] = ["events": eventCounts, "lastFlags": lastFlags, "frontmost": NSApp.isActive, "window": window.windowNumber,
                                    "frame": [window.frame.minX, window.frame.minY, window.frame.width, window.frame.height]]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) { try? data.write(to: URL(fileURLWithPath: path), options: .atomic) }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let frame = NSScreen.screens.first?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        let submenu = NSMenu()
        submenu.addItem(withTitle: "Quit Test Canvas", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = submenu; appMenu.addItem(appItem); NSApp.mainMenu = appMenu
        window = FixtureWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.title = "TinyHand test canvas"
        window.isOpaque = true; window.backgroundColor = .white
        // Menu bar tests keep native popover/menu window levels unchanged. This
        // isolated fixture still covers ordinary app windows without covering menus.
        let menuBarFixture = ProcessInfo.processInfo.environment["TINYHAND_FIXTURE_MENU_BAR"] == "1"
            && ProcessInfo.processInfo.environment["TINYHAND_FIXTURE_STATE"]?.hasPrefix("/tmp/s013-s023-") == true
        window.level = menuBarFixture ? .floating : NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        let canvas = FixtureCanvas(frame: CGRect(origin: .zero, size: frame.size))
        window.contentView = canvas
        let title = NSTextField(labelWithString: "TinyHand integration test canvas")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.frame = CGRect(x: 48, y: 40, width: 700, height: 36)
        canvas.addSubview(title)
        let subtitle = NSTextField(labelWithString: "Public fixture content only. Draw shapes in the clear area below.")
        subtitle.font = .systemFont(ofSize: 16)
        subtitle.frame = CGRect(x: 48, y: 84, width: 800, height: 28)
        canvas.addSubview(subtitle)
        let button = NSButton(title: "Click target", target: canvas, action: #selector(FixtureCanvas.clickTarget))
        button.bezelStyle = .rounded
        button.frame = CGRect(x: 48, y: 132, width: 140, height: 36)
        canvas.addSubview(button)
        let field = NSTextField(string: "")
        field.placeholderString = "Type here in Point mode"
        field.setAccessibilityLabel("Keyboard target")
        field.frame = CGRect(x: 224, y: 132, width: 320, height: 36)
        canvas.addSubview(field)
        canvas.counter.frame = CGRect(x: 48, y: 192, width: 1000, height: 28)
        canvas.counter.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        canvas.addSubview(canvas.counter)
        let menu = NSMenu()
        let action = NSMenuItem(title: "Fixture Context Action", action: #selector(FixtureCanvas.contextAction), keyEquivalent: "")
        action.target = canvas; menu.addItem(action); canvas.menu = menu
        NSApp.appearance = NSAppearance(named: .aqua)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        if ProcessInfo.processInfo.environment["TINYHAND_FIXTURE_STATE"] != nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .flagsChanged, .keyDown, .keyUp]) { [weak self] event in
                self?.eventCounts[String(event.type.rawValue), default: 0] += 1
                self?.lastFlags[String(event.type.rawValue)] = event.modifierFlags.rawValue
                self?.writeProbeState()
                return event
            }
            writeProbeState()
        }
    }
}

let app = NSApplication.shared
let delegate = FixtureDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
