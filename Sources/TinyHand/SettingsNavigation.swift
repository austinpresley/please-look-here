import Foundation

enum ToolSettingsPane: String, CaseIterable, Identifiable {
    case drawing, magnification, screenshots
    var id: String { rawValue }
    var title: String {
        switch self { case .drawing: return "Ink"; case .magnification: return "Magnifier"; case .screenshots: return "Capture" }
    }
    var symbol: String {
        switch self { case .drawing: return "pencil.tip"; case .magnification: return "plus.magnifyingglass"; case .screenshots: return "camera" }
    }
}

/// Raw section names remain compatible with existing menus and local clients.
struct SettingsRoute: Equatable {
    let section: SettingsSection
    var tool: ToolSettingsPane?
    var sound = false
    var defaults = false

    static func parse(_ name: String) -> Self? {
        switch name {
        case "tools": return Self(section: .drawing)
        case "drawing": return Self(section: .drawing, tool: .drawing)
        case "magnification", "screenshots": return Self(section: .drawing, tool: ToolSettingsPane(rawValue: name))
        case "defaults", "pointer-defaults", "effects", "appearance": return Self(section: .pointers, defaults: true)
        case "sound": return Self(section: .pointers, sound: true, defaults: true)
        case "about": return Self(section: .general)
        default: return SettingsSection(rawValue: name).map { Self(section: $0.canonical) }
        }
    }
}

enum ShortcutSettingsGroup: String, CaseIterable, Identifiable {
    case pointer, presenting, drawing, tools, quickControls, toolbar, streamDeck
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pointer: return "Pointer"
        case .presenting: return "Presenting"
        case .drawing: return "Drawing"
        case .tools: return "Tool keys"
        case .toolbar: return "Toolbar"
        case .quickControls: return "Quick controls"
        case .streamDeck: return "Stream Deck"
        }
    }
    var symbol: String {
        switch self {
        case .pointer: return "hand.point.up.left"
        case .presenting: return "camera"
        case .drawing: return "arrow.uturn.backward"
        case .tools: return "pencil.tip"
        case .quickControls: return "circle.hexagongrid"
        case .toolbar: return "rectangle.bottomthird.inset.filled"
        case .streamDeck: return "square.grid.2x2"
        }
    }

    static func containing(_ command: String) -> Self {
        if command == "radial" || command == PresentationAction.quickControls.rawValue { return .quickControls }
        if command == "toggle" { return .pointer }
        if command == "clear" { return .drawing }
        guard let action = PresentationAction(rawValue: command) else { return .pointer }
        if action.tool != nil { return .tools }
        if action.drawOnly || action == .matchInk { return .drawing }
        if [.capture, .captureRegion, .magnifier, .toolbar, .settings].contains(action) { return .presenting }
        return .pointer
    }
}

/// Ephemeral disclosure state. Every normal visit starts closed, including saved assignments.
struct ShortcutDisclosureState: Equatable {
    private(set) var expanded: Set<ShortcutSettingsGroup> = []
    mutating func set(_ group: ShortcutSettingsGroup, expanded: Bool) {
        if expanded { self.expanded.insert(group) } else { self.expanded.remove(group) }
    }
    mutating func reveal(command: String) { expanded.insert(.containing(command)) }
    mutating func reset() { expanded.removeAll() }
}

enum ScreenshotDestination: String, CaseIterable, Identifiable {
    case saveAndCopy, save, copy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .saveAndCopy: return "Save and copy"
        case .save: return "Save to folder"
        case .copy: return "Copy to clipboard"
        }
    }
    init(saves: Bool, copies: Bool) { self = saves ? (copies ? .saveAndCopy : .save) : .copy }
    var saves: Bool { self != .copy }
    var copies: Bool { self != .save }
    func apply() {
        Preferences.performBatch {
            if saves { Preferences.captureSaves = true }
            if copies { Preferences.captureCopies = true }
            Preferences.captureSaves = saves
            Preferences.captureCopies = copies
        }
    }
}
