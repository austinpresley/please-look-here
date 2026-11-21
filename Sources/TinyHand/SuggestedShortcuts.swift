import AppKit
import Carbon.HIToolbox

/// Suggestions are opt-in. They never replace an assignment, including a
/// modifier hold. Validation runs again at Apply to catch newly claimed keys.
enum SuggestedShortcuts {
    enum Assignment: Equatable {
        case key(Shortcut), hold(RadialTrigger)
        var display: String {
            switch self { case .key(let key): return key.display; case .hold(let hold): return hold.keySymbol }
        }
        var accessibilityLabel: String {
            switch self {
            case .key(let key): return key.display
            case .hold(let trigger): return "Hold \(trigger.keyName) to open Quick controls"
            }
        }
    }
    struct Item: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let assignment: Assignment
    }
    enum Status: Equatable {
        case alreadySet, willAdd, skipped(String)
        var title: String {
            switch self { case .alreadySet: return "Already set"; case .willAdd: return "Will add"; case .skipped(let reason): return "Skipped · \(reason)" }
        }
    }
    struct Row: Identifiable {
        let item: Item
        let status: Status
        var id: String { item.id }
        var assignment: Assignment? {
            guard isAssigned(item) else { return item.assignment }
            if item.id == "radial" { return Preferences.radialTrigger.map(Assignment.hold) }
            let key = item.id == "toggle" ? Preferences.toggleShortcut
                : PresentationAction(rawValue: item.id).flatMap { Preferences.shortcut(for: $0) }
            return key.map(Assignment.key)
        }
        var instruction: String { assignment?.accessibilityLabel ?? "Existing assignment kept" }
    }
    static let items: [Item] = [
        Item(id: "toggle", title: "Pointer on/off", symbol: "hand.point.up.left", assignment: .key(Shortcut(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(optionKey | cmdKey), display: "⌥⌘P"))),
        Item(id: "radial", title: "Quick controls", symbol: "circle.hexagongrid", assignment: .hold(.option)),
        Item(id: "undo", title: "Undo drawing", symbol: "arrow.uturn.backward", assignment: .key(Shortcut(keyCode: UInt32(kVK_ANSI_Z), modifiers: UInt32(optionKey | cmdKey), display: "⌥⌘Z"))),
        Item(id: "capture", title: "Screenshot", symbol: "camera", assignment: .key(Shortcut(keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(shiftKey | cmdKey), display: "⇧⌘4")))
    ]
    static let storageKeys = ["radialTrigger", "shortcut.toggle", "shortcut.clear"] + PresentationAction.allCases.map { "shortcut.\($0.rawValue)" }

    static func isAssigned(_ item: Item) -> Bool {
        // Treat any stored value as occupied. Never silently replace a legacy or
        // malformed value while filling empty commands.
        Preferences.storage.object(forKey: item.id == "radial" ? "radialTrigger" : "shortcut.\(item.id)") != nil
    }
    static func rows(check: (Item) -> String?) -> [Row] {
        items.map { item in Row(item: item, status: isAssigned(item) ? .alreadySet : check(item).map(Status.skipped) ?? .willAdd) }
    }
    static func conflict(_ item: Item, probe: (Shortcut) -> Bool = probeAvailable) -> String? {
        guard case .key(let key) = item.assignment else { return nil }
        if key.modifiers & UInt32(controlKey | optionKey) == UInt32(controlKey | optionKey) { return "VoiceOver keys" }
        if ShortcutRules.isReserved(key) || ShortcutRules.isSystemShortcut(key) { return "Used by macOS or app commands" }
        let assignments = [Preferences.toggleShortcut, Preferences.clearShortcut] + PresentationAction.allCases.map { Preferences.shortcut(for: $0) }
        if assignments.compactMap({ $0 }).contains(where: { $0.keyCode == key.keyCode && $0.modifiers == key.modifiers }) { return "Assigned to another command" }
        return probe(key) ? nil : "Unavailable in macOS or another app"
    }
    private static func probeAvailable(_ key: Shortcut) -> Bool {
        guard let token = HotKeyCenter.shared.register(keyCode: key.keyCode, modifiers: key.modifiers, action: {}) else { return false }
        HotKeyCenter.shared.unregister(token)
        return true
    }

    struct Result {
        let rows: [Row]
        let added: Int
        let alreadySet: Int
        let skipped: Int
        var summary: String { "\(added) added · \(alreadySet) already set · \(skipped) skipped" }
    }
    struct Undo {
        struct Change {
            let key: String
            let title: String
            let before: Any?
            let after: Any?
        }
        let changes: [Change]
        @discardableResult func restore() -> [String] {
            var edited: [String] = []
            Preferences.performBatch {
                for change in changes {
                    guard same(Preferences.storage.object(forKey: change.key), change.after) else {
                        edited.append(change.title); continue
                    }
                    if let value = change.before { Preferences.storage.set(value, forKey: change.key) }
                    else { Preferences.storage.removeObject(forKey: change.key) }
                }
                NotificationCenter.default.post(name: Preferences.changed, object: nil)
            }
            return edited
        }
    }
    private static func same(_ lhs: Any?, _ rhs: Any?) -> Bool {
        if lhs == nil && rhs == nil { return true }
        guard let lhs = lhs as? NSObject, let rhs = rhs as? NSObject else { return false }
        return lhs.isEqual(rhs)
    }
    static func apply(check: (Item) -> String?, assign: (Item) -> String?) -> (Result, Undo) {
        var changes: [Undo.Change] = []
        var added = 0, already = 0, skipped = 0
        let outcomes = items.map { item -> Row in
            if isAssigned(item) { already += 1; return Row(item: item, status: .alreadySet) }
            let key = item.id == "radial" ? "radialTrigger" : "shortcut.\(item.id)"
            let before = Preferences.storage.object(forKey: key)
            if let reason = check(item) ?? assign(item) { skipped += 1; return Row(item: item, status: .skipped(reason)) }
            let after = Preferences.storage.object(forKey: key)
            if !same(before, after) { changes.append(Undo.Change(key: key, title: item.title, before: before, after: after)) }
            added += 1
            return Row(item: item, status: .alreadySet)
        }
        return (Result(rows: outcomes, added: added, alreadySet: already, skipped: skipped), Undo(changes: changes))
    }
}

extension SettingsModel {
    var suggestedRows: [SuggestedShortcuts.Row] {
        SuggestedShortcuts.rows { SuggestedShortcuts.conflict($0) }
    }
    func addSuggestedShortcuts() {
        let (result, undo) = SuggestedShortcuts.apply(check: { SuggestedShortcuts.conflict($0) }) { item in
            switch item.assignment {
            case .hold(let trigger): Preferences.radialTrigger = trigger; return nil
            case .key(let key):
                let accepted: Bool
                if item.id == "toggle" { accepted = applyToggleShortcut?(key) ?? false }
                else if let action = PresentationAction(rawValue: item.id) { accepted = applyPresentationShortcut?(action, key) ?? false }
                else { accepted = false }
                return accepted ? nil : shortcutError ?? "Unavailable. Previous assignment kept."
            }
        }
        suggestedUndo = undo; suggestedResult = result; refresh()
    }
    func undoSuggestedShortcuts() {
        let edited = suggestedUndo?.restore() ?? []
        suggestedUndo = nil; suggestedResult = nil
        shortcutError = edited.isEmpty ? nil : "Kept later edits to \(edited.joined(separator: ", ")). Other suggested keys were undone."
        refresh()
    }
}
