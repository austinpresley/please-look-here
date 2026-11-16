import AppKit
import Carbon.HIToolbox
import ServiceManagement

struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var display: String

    func help(_ title: String) -> String { "\(title) (\(display))" }
}

extension Optional where Wrapped == Shortcut {
    func help(_ title: String) -> String { self?.help(title) ?? title }
}

enum InkChoice: String, CaseIterable {
    case match, red, orange, yellow, green, blue, purple, white, black

    var title: String {
        switch self {
        case .match: return "Match the pointer"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .white: return "White"
        case .black: return "Black"
        }
    }

    var color: CGColor? {
        switch self {
        case .match: return nil
        case .red: return Ink.red
        case .orange: return Ink.hex(0xFF8A00)
        case .yellow: return Ink.hex(0xFFCC00)
        case .green: return Ink.hex(0x30C25A)
        case .blue: return Ink.hex(0x0A84FF)
        case .purple: return Ink.hex(0x8754F2)
        case .white: return Ink.hex(0xFFFFFF)
        case .black: return Ink.hex(0x1D1D21)
        }
    }

    func resolved(for style: PointerStyle) -> CGColor {
        color ?? style.inkColor
    }
}

enum Preferences {
    static let changed = Notification.Name("TinyHandPreferencesChanged")
    private static let defaults = ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"].flatMap(UserDefaults.init(suiteName:)) ?? .standard
    static var storage: UserDefaults { defaults }
    private static var batchDepth = 0

    static func performBatch(_ changes: () -> Void) {
        batchDepth += 1
        changes()
        batchDepth -= 1
        if batchDepth == 0 { NotificationCenter.default.post(name: changed, object: nil) }
    }

    static var pointerMode: PointerMode {
        get { defaults.string(forKey: "pointerMode").flatMap(PointerMode.init(rawValue:)) ?? .point }
        set { set(newValue.rawValue, "pointerMode") }
    }

    static var drawingTool: DrawingTool {
        get { defaults.string(forKey: "drawingTool").flatMap(DrawingTool.init(rawValue:)) ?? .pen }
        set { set(newValue.rawValue, "drawingTool") }
    }

    static var strokeWidth: CGFloat {
        get { CGFloat(min(20, max(2, defaults.object(forKey: "strokeWidth") as? Double ?? 6))) }
        set { set(Double(min(20, max(2, newValue))), "strokeWidth") }
    }

    static var inkOpacity: CGFloat {
        get { CGFloat(min(1, max(0.1, defaults.object(forKey: "inkOpacity") as? Double ?? 1))) }
        set { set(Double(min(1, max(0.1, newValue))), "inkOpacity") }
    }

    static var strokeSmoothing: StrokeSmoothing {
        get { StrokeSmoothing(rawValue: defaults.object(forKey: "strokeSmoothing") as? Int ?? 2) ?? .light }
        set { set(newValue.rawValue, "strokeSmoothing") }
    }

    static var pointerMotion: PointerMotion {
        get { defaults.string(forKey: "pointerMotion").flatMap(PointerMotion.init(rawValue:)) ?? .original }
        set { set(newValue.rawValue, "pointerMotion") }
    }

    static var theme: AppTheme {
        get { defaults.string(forKey: "theme").flatMap(AppTheme.init(rawValue:)) ?? .system }
        set { set(newValue.rawValue, "theme") }
    }

    static var showToolbar: Bool {
        get { defaults.object(forKey: "showToolbar") as? Bool ?? true }
        set { set(newValue, "showToolbar") }
    }

    static var toolbarPosition: CGPoint? {
        get {
            guard let value = defaults.array(forKey: "toolbarPosition") as? [Double], value.count == 2 else { return nil }
            return CGPoint(x: value[0], y: value[1])
        }
        set {
            if let p = newValue { set([Double(p.x), Double(p.y)], "toolbarPosition") }
            else { defaults.removeObject(forKey: "toolbarPosition"); NotificationCenter.default.post(name: changed, object: nil) }
        }
    }

    static func recordToolbarPosition(_ point: CGPoint) {
        // A drag already moved the panel. Saving it must not relayout that panel.
        defaults.set([Double(point.x), Double(point.y)], forKey: "toolbarPosition")
    }

    static var captureCopies: Bool {
        get { defaults.object(forKey: "capture.copy") as? Bool ?? true }
        set { set(newValue, "capture.copy") }
    }

    static var captureSaves: Bool {
        get { defaults.object(forKey: "capture.save") as? Bool ?? true }
        set { set(newValue, "capture.save") }
    }

    static var captureFolder: URL {
        get {
            if let path = defaults.string(forKey: "capture.folder") { return URL(fileURLWithPath: path, isDirectory: true) }
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
        }
        set { set(newValue.path, "capture.folder") }
    }

    static func shortcut(for action: PresentationAction) -> Shortcut? {
        loadShortcut("shortcut.\(action.rawValue)")
    }

    static func setShortcut(_ shortcut: Shortcut?, for action: PresentationAction) {
        saveShortcut(shortcut, "shortcut.\(action.rawValue)")
    }

    static var radialTrigger: RadialTrigger? {
        get { defaults.string(forKey: "radialTrigger").flatMap(RadialTrigger.init(rawValue:)) }
        set {
            if let newValue { set(newValue.rawValue, "radialTrigger") }
            else { defaults.removeObject(forKey: "radialTrigger"); NotificationCenter.default.post(name: changed, object: nil) }
        }
    }

    static var toggleShortcut: Shortcut? {
        get { loadShortcut("shortcut.toggle") }
        set { saveShortcut(newValue, "shortcut.toggle") }
    }

    static var clearShortcut: Shortcut? {
        get { loadShortcut("shortcut.clear") }
        set { saveShortcut(newValue, "shortcut.clear") }
    }

    static var shortcutState: [String: Any] {
        var values: [String: Shortcut?] = ["toggle": toggleShortcut, "clear": clearShortcut]
        for action in PresentationAction.allCases { values[action.rawValue] = .some(shortcut(for: action)) }
        return values.mapValues { value -> Any in
            guard let value else { return NSNull() }
            return ["keyCode": value.keyCode, "modifiers": value.modifiers, "display": value.display]
        }
    }

    static let pointerSizeRange: ClosedRange<CGFloat> = 0.04...0.20

    static var pointerSize: CGFloat {
        get { (defaults.object(forKey: "pointerSize") as? Double).map { CGFloat($0) } ?? 0.13 }
        set { set(Double(newValue), "pointerSize") }
    }

    static var showShadow: Bool {
        get { defaults.object(forKey: "showShadow") as? Bool ?? true }
        set { set(newValue, "showShadow") }
    }

    static var shadowStyle: PointerShadowStyle {
        get { defaults.string(forKey: "shadowStyle").flatMap(PointerShadowStyle.init(rawValue:)) ?? .original }
        set { set(newValue.rawValue, "shadowStyle") }
    }

    static var fadeSeconds: Double {
        get { defaults.object(forKey: "fadeSeconds") as? Double ?? 3 }
        set { set(newValue, "fadeSeconds") }
    }

    static var inkFadeStyle: InkFadeStyle {
        get { defaults.string(forKey: "inkFadeStyle").flatMap(InkFadeStyle.init(rawValue:)) ?? (fadeSeconds <= 0 ? .permanent : .wholeLine) }
        set { performBatch {
            set(newValue.rawValue, "inkFadeStyle")
            if newValue != .permanent && fadeSeconds <= 0 { fadeSeconds = 3 }
        } }
    }
    static var trailDelay: Double {
        get { min(3, max(0.2, defaults.object(forKey: "trailDelay") as? Double ?? 1)) }
        set { set(min(3, max(0.2, newValue)), "trailDelay") }
    }
    static var trailSpeed: Double {
        get { min(600, max(40, defaults.object(forKey: "trailSpeed") as? Double ?? 240)) }
        set { set(min(600, max(40, newValue)), "trailSpeed") }
    }
    static var magnifierZoom: Double {
        get { min(6, max(1.5, defaults.object(forKey: "magnifierZoom") as? Double ?? 3)) }
        set { set(min(6, max(1.5, newValue)), "magnifierZoom") }
    }
    static var magnifierDiameter: Double {
        get { min(480, max(160, defaults.object(forKey: "magnifierDiameter") as? Double ?? 240)) }
        set { set(min(480, max(160, newValue)), "magnifierDiameter") }
    }
    static var tapSwing: Double {
        get { min(2, max(0, defaults.object(forKey: "tapSwing") as? Double ?? 0)) }
        set { set(min(2, max(0, newValue)), "tapSwing") }
    }

    static var handSound: Bool {
        get { defaults.object(forKey: "sound.hands") as? Bool ?? true }
        set { set(newValue, "sound.hands") }
    }

    static var tapSound: TapSoundChoice {
        get { defaults.string(forKey: "tapSound").flatMap(TapSoundChoice.init(rawValue:)) ?? .thock }
        set { set(newValue.rawValue, "tapSound") }
    }

    static var laserSound: Bool {
        get { pointerConfiguration(for: "laser").soundEnabled }
        set {
            performBatch {
                // Keep the old key for older app versions and configure clients.
                set(newValue, "sound.laser")
                try? updatePointer("laser") { $0.soundEnabled = newValue }
            }
        }
    }

    static var interactKeepsHand: Bool {
        get { defaults.object(forKey: "interactKeepsHand") as? Bool ?? true }
        set { set(newValue, "interactKeepsHand") }
    }

    static var inkChoice: InkChoice {
        get { defaults.string(forKey: "inkChoice").flatMap(InkChoice.init(rawValue:)) ?? .match }
        set { set(newValue.rawValue, "inkChoice") }
    }

    static var showInkButton: Bool {
        get { defaults.object(forKey: "showInkButton") as? Bool ?? true }
        set { set(newValue, "showInkButton") }
    }

    static let maxPinned = 8

    static var disabledPointerIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "disabledPointerIDs") ?? []) }
        set { set(newValue.sorted(), "disabledPointerIDs") }
    }

    static var pinnedStyles: [PointerStyle] {
        get {
            guard let raw = defaults.stringArray(forKey: "pinnedStyles") else {
                return PointerStyle.defaultPinned
            }
            var seen = Set<PointerStyle>()
            let pinned = raw.compactMap(PointerStyle.init(rawValue:)).filter { seen.insert($0).inserted }
            return pinned.isEmpty ? PointerStyle.defaultPinned : pinned
        }
        set { set(newValue.map(\.rawValue), "pinnedStyles") }
    }

    static var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Log.write("launch at login change failed: \(error.localizedDescription)")
            }
            NotificationCenter.default.post(name: changed, object: nil)
        }
    }

    static func resetAll() {
        for key in ["radialTrigger", "shortcut.toggle", "shortcut.clear", "pointerSize", "showShadow", "shadowStyle", "fadeSeconds",
                    "sound.hands", "sound.laser", "interactKey", "interactKeepsHand", "pinnedStyles", "pointerStyle", "disabledPointerIDs",
                    "inkChoice", "showInkButton", "tapSound", "pointerMode", "drawingTool", "strokeWidth", "inkOpacity",
                    "strokeSmoothing", "pointerMotion", "theme", "showToolbar", "toolbarPosition", "capture.copy", "capture.save", "capture.folder",
                    "inkFadeStyle", "trailDelay", "trailSpeed", "magnifierZoom", "magnifierDiameter", "tapSwing", PointerConfigurationDocument.storageKey]
                    + PresentationAction.allCases.map({ "shortcut.\($0.rawValue)" }) {
            defaults.removeObject(forKey: key)
        }
        if batchDepth == 0 { NotificationCenter.default.post(name: changed, object: nil) }
    }

    private static func set(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
        if batchDepth == 0 { NotificationCenter.default.post(name: changed, object: nil) }
    }

    static func notifyPointerConfigurationChanged() {
        if batchDepth == 0 { NotificationCenter.default.post(name: changed, object: nil) }
    }

    private static func loadShortcut(_ key: String) -> Shortcut? {
        guard let d = defaults.dictionary(forKey: key),
              let code = d["keyCode"] as? Int, let mods = d["modifiers"] as? Int, let label = d["display"] as? String,
              (0...127).contains(code), mods >= 0, mods <= Int(UInt32.max), !label.isEmpty else {
            return nil
        }
        return Shortcut(keyCode: UInt32(code), modifiers: UInt32(mods), display: label)
    }

    private static func saveShortcut(_ s: Shortcut?, _ key: String) {
        if let s {
            set(["keyCode": Int(s.keyCode), "modifiers": Int(s.modifiers), "display": s.display], key)
        } else {
            defaults.removeObject(forKey: key)
            if batchDepth == 0 { NotificationCenter.default.post(name: changed, object: nil) }
        }
    }
}
