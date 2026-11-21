import SwiftUI

struct ShortcutsPage: View {
    @ObservedObject var model: SettingsModel
    private let pointer: [String] = ["toggle", "exitPointer", "mode", "nextPointer", "previousPointer", "sound", "gesture1", "gesture2"]
    private let presenting: [String] = ["capture", "capture-region", "magnifier", "toolbar", "settings"]
    private let drawing: [String] = ["clear", "undo", "redo", "matchInk"]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            suggestedCard.gridProbe("shortcuts.suggested", area: "shortcuts")
            if !model.shortcutConflicts.isEmpty {
                HStack(spacing: Space.md) {
                    Label("\(model.shortcutConflicts.count) shortcut conflicts", systemImage: "exclamationmark.triangle")
                    Spacer()
                    Button("Show First") {
                        if let command = model.shortcutConflicts.keys.sorted().first { model.focusShortcut(command: command) }
                    }
                }.font(.system(size: 12)).padding(Space.md)
                    .background(RoundedRectangle(cornerRadius: Space.sm).fill(Color.primary.opacity(0.06)))
            }
            HStack(spacing: Space.sm) {
                TextField("Search \(matchingCount) commands", text: Binding(get: { model.shortcutQuery }, set: { model.shortcutQuery = $0; updateSearch() }))
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Find a shortcut command")
                Toggle(isOn: Binding(get: { model.shortcutAssignedOnly }, set: { model.shortcutAssignedOnly = $0; updateSearch() }))
                    { Image(systemName: "checklist") }.toggleStyle(.button)
                    .help("Show assigned commands only").accessibilityLabel("Assigned only")
            }.gridProbe("shortcuts.search", area: "shortcuts")
            ForEach(ShortcutSettingsGroup.allCases) { group in
                if visible(group) {
                    SettingsDisclosure(title: group.title, summary: summary(group), symbol: group.symbol, compact: true, glyph: group == .quickControls ? .wheel : nil, isExpanded: model.shortcutExpansion(group)) {
                        contents(group)
                    }
                    .id(group)
                    .gridProbe("shortcuts.\(group.rawValue)", area: "shortcuts", edge: "lead")
                }
            }
            if !ShortcutSettingsGroup.allCases.contains(where: visible) {
                SettingsSubtitle("No matching commands. Change the search or turn off Assigned only.")
            }
            if let error = model.shortcutError { Text(error).font(.callout).foregroundStyle(.red) }
        }
        .gridArea("shortcuts", inset: 0)
    }

    private var matchingCount: Int { ShortcutSettingsGroup.allCases.flatMap(commands).filter(matches).count }
    private var suggestedCard: some View {
        let rows = model.suggestedRows
        let count = rows.filter { $0.status == .willAdd }.count
        return Card(title: nil) {
            HStack(spacing: Space.sm) {
                Label("Suggested", systemImage: "wand.and.stars").font(.headline)
                Spacer()
                Text("Empty commands only").font(.system(size: 11)).foregroundStyle(.secondary)
                Button { model.addSuggestedShortcuts() } label: { Label("Add \(count)", systemImage: "checkmark") }
                    .disabled(count == 0).accessibilityIdentifier("shortcuts.suggested.add")
            }.padding(Space.md)
            ForEach(rows) { row in
                HStack(spacing: Space.sm) {
                    commandImage(row.item.id).frame(width: 20).foregroundStyle(.secondary)
                    Text(row.item.title).font(.system(size: 12))
                    Spacer(minLength: Space.sm)
                    Text(row.status.title).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Space.xs) {
                        if let assignment = row.assignment {
                            if case .hold = assignment { Text("Hold").font(.system(size: 12, weight: .medium)) }
                            ShortcutKeycaps(display: assignment.display)
                        } else { Text("Existing assignment kept").font(.system(size: 11)).foregroundStyle(.secondary) }
                    }.accessibilityElement(children: .ignore).accessibilityLabel(row.instruction)
                }.padding(.horizontal, Space.md).padding(.vertical, Space.sm)
            }
            if let result = model.suggestedResult {
                HStack(spacing: Space.sm) {
                    Label(result.summary, systemImage: "checkmark.circle").font(.system(size: 12))
                    Spacer()
                    Button("Undo") { model.undoSuggestedShortcuts() }.disabled(model.suggestedUndo == nil)
                }.padding(Space.md).accessibilityIdentifier("shortcuts.suggested.result")
            }
        }
    }
    @ViewBuilder private func commandImage(_ command: String) -> some View {
        if command == "radial" || command == "quick-controls" {
            Image(nsImage: UsabilityGlyph.wheel.image).resizable().scaledToFit().frame(width: 20, height: 20)
        } else if let slot = PresentationAction(rawValue: command)?.gesture,
                  let image = ShortcutGestureArtwork.image(slot, style: .saved) {
            Image(nsImage: image).resizable().scaledToFit().frame(width: 28, height: 28)
                .accessibilityLabel(slot.stockTitle)
        } else { Image(systemName: commandSymbol(command)) }
    }
    private func commandSymbol(_ command: String) -> String {
        if let tool = PresentationAction(rawValue: command)?.tool { return tool.symbol }
        switch command {
        case "toggle": return "hand.point.up.left"
        case "exitPointer": return "hand.raised.slash"
        case "mode": return "cursorarrow"
        case "nextPointer": return "forward.end"
        case "previousPointer": return "backward.end"
        case "sound": return "speaker.wave.2"
        case "gesture1": return "hand.point.up.left"
        case "gesture2": return "hand.wave"
        case "capture", "capture-region": return "camera"
        case "magnifier": return "plus.magnifyingglass"
        case "toolbar": return "rectangle.bottomthird.inset.filled"
        case "settings": return "gearshape"
        case "clear": return "trash"
        case "undo": return "arrow.uturn.backward"
        case "redo": return "arrow.uturn.forward"
        case "matchInk": return "paintpalette"
        default: return "circle.hexagongrid"
        }
    }

    private func commands(_ group: ShortcutSettingsGroup) -> [String] {
        switch group {
        case .pointer: return pointer
        case .presenting: return presenting
        case .drawing: return drawing
        case .tools: return PresentationAction.allCases.filter { $0.tool != nil }.map(\.rawValue)
        case .quickControls: return ["radial", "quick-controls"]
        case .toolbar, .streamDeck: return []
        }
    }
    private func title(_ command: String) -> String {
        switch command {
        case "toggle": return "Pointer On/Off"
        case "clear": return "Clear Drawing"
        case "radial": return "Hold to open"
        default:
            if let slot = PresentationAction(rawValue: command)?.gesture { return "Hold \(slot.stockTitle) gesture" }
            return PresentationAction(rawValue: command)?.title ?? command
        }
    }
    private func shortcut(_ command: String) -> Shortcut? {
        if command == "toggle" { return Preferences.toggleShortcut }
        if command == "clear" { return Preferences.clearShortcut }
        return PresentationAction(rawValue: command).flatMap { Preferences.shortcut(for: $0) }
    }
    private func matches(_ command: String) -> Bool {
        let search = model.shortcutQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return (search.isEmpty || title(command).localizedStandardContains(search)) &&
            (!model.shortcutAssignedOnly || (command == "radial" ? Preferences.radialTrigger != nil : shortcut(command) != nil))
    }
    private func visible(_ group: ShortcutSettingsGroup) -> Bool {
        if !commands(group).isEmpty { return commands(group).contains(where: matches) }
        return !model.shortcutAssignedOnly && (model.shortcutQuery.isEmpty || group.title.localizedStandardContains(model.shortcutQuery))
    }
    private func summary(_ group: ShortcutSettingsGroup) -> String {
        if group == .toolbar { return Preferences.showToolbar ? "Shown" : "Hidden" }
        if group == .streamDeck { return "Plugin setup" }
        let conflicts = commands(group).filter { model.shortcutConflicts[$0] != nil }.count
        let set = commands(group).filter { $0 == "radial" ? Preferences.radialTrigger != nil : shortcut($0) != nil }.count
        return "\(set) of \(commands(group).count) assigned" + (conflicts > 0 ? " · \(conflicts) conflicts" : "")
    }
    private func updateSearch() {
        model.cancelShortcutNavigation()
        if model.shortcutQuery.isEmpty && !model.shortcutAssignedOnly { model.shortcutDisclosure.reset(); return }
        for group in ShortcutSettingsGroup.allCases { model.shortcutDisclosure.set(group, expanded: visible(group)) }
    }

    @ViewBuilder private func contents(_ group: ShortcutSettingsGroup) -> some View {
        switch group {
        case .pointer, .presenting, .drawing, .tools:
            ForEach(commands(group).filter(matches), id: \.self) { command in commandRow(command) }
            if group == .tools { SettingsSubtitle("Single-letter keys work here. They pause while you type.").padding(Space.md) }
        case .toolbar:
            Row("Show toolbar", detail: "Reveals at pointer startup and while the cursor is nearby.") {
                Toggle("Show toolbar", isOn: model.binding({ Preferences.showToolbar }, { Preferences.showToolbar = $0 })).labelsHidden().toggleStyle(.switch)
            }
            Row("Position") { Button("Reset Position") { Preferences.toolbarPosition = nil } }
        case .quickControls:
            if matches("radial") {
                Row("Hold to open", detail: "Needs Pointer On and Accessibility.", symbol: nil) {
                    Image(nsImage: UsabilityGlyph.wheel.image).resizable().scaledToFit().frame(width: 20, height: 20)
                    ShortcutModifierPicker(selection: model.binding({ Preferences.radialTrigger?.rawValue ?? "" }, { Preferences.radialTrigger = RadialTrigger(rawValue: $0) })).frame(width: 144)
                    Button("Clear") { Preferences.radialTrigger = nil; model.refresh() }.disabled(Preferences.radialTrigger == nil)
                }.id("radial")
            }
            if matches("quick-controls") { commandRow("quick-controls") }
            Row("Practice", detail: "Hold, move to a choice, then release. Center release or Escape cancels.") {
                Button("Try It…") { model.openPractice?(.radial) }
                Button("Favorites…") { model.section = .pointers }
            }
        case .streamDeck: StreamDeckSettings(title: nil)
        }
    }
    private func commandHelp(_ command: String) -> String {
        if let slot = PresentationAction(rawValue: command)?.gesture { return "Hold for the \(slot.stockTitle) gesture while an available hand is on." }
        if command == "toggle" || command == "clear" { return "Global. Works with the pointer off." }
        if command == "sound" { return "Current pointer only. App mute still applies." }
        return "Click the field to assign keys. Esc cancels."
    }
    private func commandRow(_ command: String) -> some View {
        let action = PresentationAction(rawValue: command)
        return HStack(spacing: Space.sm) {
            commandImage(command).frame(width: 28).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(title(command)).font(.system(size: 12))
            Spacer(minLength: Space.sm)
            ShortcutField(shortcut: shortcut(command), model: model, command: command, label: title(command), allowsPlainKeys: action?.tool != nil) { value in
                if command == "toggle" { return model.applyToggleShortcut?(value) ?? false }
                if command == "clear" { return model.applyClearShortcut?(value) ?? false }
                return action.map { model.applyPresentationShortcut?($0, value) ?? false } ?? false
            }
        }.padding(.horizontal, Space.sm).padding(.vertical, 2).frame(minHeight: 36)
        .help(commandHelp(command))
        .id(command)
        .overlay(RoundedRectangle(cornerRadius: Space.sm).strokeBorder(model.shortcutFocusRequest?.controlIdentifier == "settings.shortcut.\(command)" ? Color.accentColor : .clear, lineWidth: 2))
    }
}

struct ShortcutKeycaps: View {
    let display: String
    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(Array(display.enumerated()), id: \.offset) { _, character in
                Text(String(character)).font(.system(size: 12, weight: .medium))
                    .frame(minWidth: 16).padding(.horizontal, Space.xs).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: Space.xs).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: Space.xs).strokeBorder(Color.primary.opacity(0.14)))
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel(display)
    }
}

/// Always show the actual pose, even when a non-hand pointer is current.
enum ShortcutGestureArtwork {
    static func image(_ slot: HandGestureSlot, style: PointerStyle) -> NSImage? {
        if let base = style.assetName.flatMap(HandAsset.load), let pose = HandGestureCatalog.image(slot, style: style) {
            return base.replacingImage(pose).thumbnail
        }
        return HandAsset.load(slot.assetName)?.thumbnail
    }
}
