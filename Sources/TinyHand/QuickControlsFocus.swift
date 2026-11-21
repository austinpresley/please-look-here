import AppKit

/// Native focus operations are injectable so panel handoffs can be tested without
/// activating another app or posting input into the user's session.
struct QuickControlsFocus {
    struct Context {
        var app: NSRunningApplication?
        weak var window: NSWindow?
        weak var responder: NSResponder?
    }
    var capture: () -> Context
    var focus: (NSWindow, NSResponder?, Bool) -> Bool
    var isKey: (NSWindow) -> Bool
    var isActive: () -> Bool = { NSApp.isActive }
    var restore: (Context) -> Void

    static var system: Self {
        Self(capture: {
            Context(app: NSWorkspace.shared.frontmostApplication, window: NSApp.keyWindow, responder: NSApp.keyWindow?.firstResponder)
        }, focus: { window, responder, activate in
            if activate { NSApp.activate(ignoringOtherApps: true) }
            window.makeKeyAndOrderFront(nil); window.makeFirstResponder(responder)
            return window.isKeyWindow
        }, isKey: { $0.isKeyWindow }, restore: { context in
            if let window = context.window, window.isVisible, window.canBecomeKey {
                window.makeKey()
                if let responder = context.responder { window.makeFirstResponder(responder) }
            }
            if let app = context.app, app.processIdentifier != getpid(), !app.isTerminated { app.activate(options: []) }
        })
    }
    func save() -> QuickControlsFocusRestoration { QuickControlsFocusRestoration(context: capture(), restore: restore) }
}

/// One restoration obligation. Taking it from an owner clears that owner's
/// reference; consumption clears the action before any reentrant focus callback.
final class QuickControlsFocusRestoration {
    private let context: QuickControlsFocus.Context
    private var action: ((QuickControlsFocus.Context) -> Void)?
    init(context: QuickControlsFocus.Context, restore: @escaping (QuickControlsFocus.Context) -> Void) {
        self.context = context; action = restore
    }
    func restore() {
        let restore = action; action = nil; restore?(context)
    }
}
