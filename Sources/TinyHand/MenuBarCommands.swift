import AppKit
import Carbon.HIToolbox

/// Native secondary commands share requests and observed state with the panel.
final class MenuBarCommands: NSObject {
    let menu = NSMenu(title: "Look Here Please")
    var perform: (([String: Any]) -> Void)?
    var openControls: (() -> Void)?
    var checkForUpdates: (() -> Void)?
    private var requests: [NSMenuItem: [String: Any]] = [:]
    private var items: [String: NSMenuItem] = [:]
    private let pointers = NSMenu(title: "Choose Pointer")
    private let colors = NSMenu(title: "Ink Color")
    private var catalog: [PointerStyle] = []
    private let overlay: OverlayController

    init(overlay: OverlayController) {
        self.overlay = overlay
        super.init()
        menu.autoenablesItems = false
        let show = NSMenuItem(title: "Open Controls", action: #selector(showControls), keyEquivalent: "")
        show.target = self; menu.addItem(show)
        menu.addItem(.separator())
        let pointer = group("Pointer")
        add("toggle", "Turn Pointer On", "toggle", to: pointer)
        add("interact", "Interact", "interact", ["enabled": true], to: pointer)
        submenu("Choose Pointer", pointers, to: pointer)
        let gestures = NSMenu(title: "Hand Gestures")
        submenu("Hand Gestures", gestures, to: pointer)
        for slot in HandGestureSlot.allCases {
            add(slot.action.rawValue, "Show \(slot.title)", "gesture", ["slot": slot.rawValue], to: gestures)
        }
        add("gestureArtwork", "Edit Gesture Artwork…", "settings", ["section": "pointers"], to: gestures)
        add("sound", "Tap Sound", "toggle-current-sound", to: pointer)
        let drawing = group("Drawing")
        for tool in DrawingTool.allCases { add(tool.rawValue, tool.title, "tool", ["tool": tool.rawValue], to: drawing) }
        submenu("Ink Color", colors, to: drawing)
        drawing.addItem(.separator())
        add("undo", "Undo Annotation", "undo", to: drawing)
        add("redo", "Redo Annotation", "redo", to: drawing)
        add("clear", "Clear Drawing", "clear", to: drawing)
        let presentation = group("Presentation")
        add("capture", "Take Screenshot", "capture", to: presentation)
        add("capture-region", "Capture Region…", "capture-region", to: presentation)
        add("magnifier", "Magnification", "magnifier", ["enabled": true], to: presentation)
        add("toolbar", "Show Toolbar", "configure", ["settings": ["showToolbar": true]], to: presentation)
        menu.addItem(.separator())
        add("permission", "Allow Drawing…", "settings", ["section": "general"], to: menu)
        add("settings", "Settings…", "settings", to: menu)
        if Updater.isAvailable {
            let update = NSMenuItem(title: "Check for Updates…", action: #selector(update), keyEquivalent: "")
            update.target = self; menu.addItem(update)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Look Here Please", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; quit.keyEquivalentModifierMask = .command; menu.addItem(quit)
        refresh()
    }
    private func group(_ title: String) -> NSMenu {
        let child = NSMenu(title: title); child.autoenablesItems = false
        submenu(title, child, to: menu)
        return child
    }
    private func submenu(_ title: String, _ child: NSMenu, to parent: NSMenu) {
        child.autoenablesItems = false
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = child; parent.addItem(item)
    }
    private func add(_ id: String, _ title: String, _ op: String, _ fields: [String: Any] = [:], to parent: NSMenu) {
        let item = NSMenuItem(title: title, action: #selector(invoke(_:)), keyEquivalent: "")
        item.target = self; parent.addItem(item); items[id] = item
        requests[item] = fields.merging(["version": 1, "operation": op]) { _, b in b }
    }
    func refresh() {
        let appearance = NSApp.effectiveAppearance
        for menu in allMenus where menu.appearance?.name != appearance.name { menu.appearance = appearance }
        let styles = PointerCatalog.selectableStyles
        if styles != catalog || pointers.items.map(\.title) != styles.map(\.title) {
            pointers.items.forEach { requests[$0] = nil }; pointers.removeAllItems(); catalog = styles
            for style in styles {
                let item = NSMenuItem(title: style.title, action: #selector(invoke(_:)), keyEquivalent: "")
                item.target = self; item.representedObject = style.rawValue
                requests[item] = ["version": 1, "operation": "style", "style": style.rawValue]
                pointers.addItem(item)
            }
        }
        if colors.items.isEmpty {
            for color in InkChoice.allCases {
                let item = NSMenuItem(title: color.title, action: #selector(invoke(_:)), keyEquivalent: "")
                item.target = self; item.representedObject = color.rawValue
                requests[item] = ["version": 1, "operation": "configure", "settings": ["ink": color.rawValue]]
                colors.addItem(item)
            }
        }
        for item in pointers.items { item.state = item.representedObject as? String == overlay.style.rawValue ? .on : .off }
        for slot in HandGestureSlot.allCases {
            let item = items[slot.action.rawValue]
            item?.title = "Show \(slot.title) · \(HandGestureCatalog.hasCustom(slot, style: overlay.style) ? "Custom" : slot.stockTitle)"
            item?.state = overlay.activeGesture == slot ? .on : .off
            item?.isEnabled = overlay.style.assetName != nil && !overlay.isCapturing && HandGestureCatalog.image(slot, style: overlay.style) != nil
            item?.toolTip = "Show this pose for two seconds. Assign a hold shortcut in Settings."
        }
        for item in colors.items { item.state = item.representedObject as? String == Preferences.inkChoice.rawValue ? .on : .off }
        items["toggle"]?.title = overlay.isActive ? "Turn Pointer Off" : "Turn Pointer On"
        items["interact"]?.state = overlay.mode.isInteractive ? .on : .off
        items["interact"]?.isEnabled = !overlay.isCapturing && (overlay.mode == .draw || overlay.drawingAllowed)
        if let item = items["interact"] { requests[item] = ["version": 1, "operation": "interact", "enabled": !overlay.mode.isInteractive] }
        items["sound"]?.state = overlay.soundOn ? .on : .off
        items["undo"]?.isEnabled = overlay.canUndo && !overlay.isCapturing
        items["redo"]?.isEnabled = overlay.canRedo && !overlay.isCapturing
        items["clear"]?.isEnabled = overlay.inkStrokes > 0 && !overlay.isCapturing
        items["capture"]?.isEnabled = !overlay.isCapturing
        items["capture-region"]?.isEnabled = !overlay.isCapturing && !overlay.isSelectingScreenshotRegion
        items["capture"]?.title = overlay.isCapturing ? "Taking Screenshot…" : "Take Screenshot"
        items["magnifier"]?.state = overlay.isMagnifying ? .on : .off
        items["magnifier"]?.isEnabled = !overlay.isCapturing
        if let item = items["magnifier"] { requests[item] = ["version": 1, "operation": "magnifier", "enabled": !overlay.isMagnifying] }
        items["permission"]?.isHidden = overlay.drawingAllowed
        items["toolbar"]?.state = Preferences.showToolbar ? .on : .off
        items["toolbar"]?.title = Preferences.showToolbar ? "Hide Toolbar" : "Show Toolbar"
        if let item = items["toolbar"] { requests[item] = ["version": 1, "operation": "configure", "settings": ["showToolbar": !Preferences.showToolbar]] }
        for tool in DrawingTool.allCases {
            items[tool.rawValue]?.state = Preferences.drawingTool == tool ? .on : .off
            items[tool.rawValue]?.isEnabled = overlay.drawingAllowed && !overlay.isCapturing
        }
        Self.shortcut(Preferences.toggleShortcut, on: items["toggle"])
        Self.shortcut(Preferences.clearShortcut, on: items["clear"])
        for action in PresentationAction.allCases { Self.shortcut(Preferences.shortcut(for: action), on: items[action.rawValue == "mode" ? "interact" : action.rawValue]) }
    }
    var diagnostics: [[String: Any]] {
        func walk(_ menu: NSMenu) -> [[String: Any]] { menu.items.filter { !$0.isSeparatorItem }.map { item in
            ["title": item.title, "enabled": item.isEnabled, "selected": item.state == .on, "hidden": item.isHidden,
             "key": item.keyEquivalent, "modifiers": item.keyEquivalentModifierMask.rawValue, "children": item.submenu.map(walk) ?? []]
        } }
        return walk(menu)
    }
    var allMenus: [NSMenu] {
        func walk(_ menu: NSMenu) -> [NSMenu] { [menu] + menu.items.compactMap(\.submenu).flatMap(walk) }
        return walk(menu)
    }
    @objc private func invoke(_ item: NSMenuItem) { if let request = requests[item] { perform?(request) }; refresh() }
    @objc private func showControls() { openControls?() }
    @objc private func update() { checkForUpdates?() }
    @objc private func quit() { NSApp.terminate(nil) }

    static func shortcut(_ shortcut: Shortcut?, on item: NSMenuItem?) {
        guard let shortcut else { item?.keyEquivalent = ""; item?.keyEquivalentModifierMask = []; return }
        let codes: [Int: UInt32] = [kVK_LeftArrow: 0xF702, kVK_RightArrow: 0xF703, kVK_UpArrow: 0xF700, kVK_DownArrow: 0xF701,
            kVK_Home: 0xF729, kVK_End: 0xF72B, kVK_PageUp: 0xF72C, kVK_PageDown: 0xF72D, kVK_ForwardDelete: 0xF728,
            kVK_F1: 0xF704, kVK_F2: 0xF705, kVK_F3: 0xF706, kVK_F4: 0xF707, kVK_F5: 0xF708, kVK_F6: 0xF709,
            kVK_F7: 0xF70A, kVK_F8: 0xF70B, kVK_F9: 0xF70C, kVK_F10: 0xF70D, kVK_F11: 0xF70E, kVK_F12: 0xF70F]
        var special = Dictionary(uniqueKeysWithValues: codes.map { (UInt32($0.key), String(UnicodeScalar($0.value)!)) })
        special[UInt32(kVK_Space)] = " "; special[UInt32(kVK_Return)] = "\r"; special[UInt32(kVK_Tab)] = "\t"; special[UInt32(kVK_Delete)] = "\u{7F}"
        item?.keyEquivalent = special[shortcut.keyCode] ?? shortcut.display.filter { !"⌃⌥⇧⌘".contains($0) }.lowercased()
        var flags: NSEvent.ModifierFlags = []
        if shortcut.modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if shortcut.modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if shortcut.modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if shortcut.modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        item?.keyEquivalentModifierMask = flags
    }
}
