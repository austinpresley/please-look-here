import AppKit

final class FixtureWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class FixtureCanvas: NSView {
    let counter = NSTextField(labelWithString: "Button clicks: 0 · Canvas down: 0 · Canvas up: 0 · Drags: 0")
    private var buttonClicks = 0, downs = 0, ups = 0, drags = 0
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { NSColor.white.setFill(); dirtyRect.fill() }
    override func mouseDown(with event: NSEvent) { downs += 1; refresh() }
    override func mouseUp(with event: NSEvent) { ups += 1; refresh() }
    override func mouseDragged(with event: NSEvent) { drags += 1; refresh() }
    @objc func clickTarget() { buttonClicks += 1; refresh() }
    @objc func contextAction() { buttonClicks += 10; refresh() }
    private func refresh() { counter.stringValue = "Button clicks: \(buttonClicks) · Canvas down: \(downs) · Canvas up: \(ups) · Drags: \(drags)" }
}

final class FixtureDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
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
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
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
    }
}

let app = NSApplication.shared
let delegate = FixtureDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
