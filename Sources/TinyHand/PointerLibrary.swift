import SwiftUI

struct PointerLibrary: View {
    @ObservedObject var model: SettingsModel
    @State private var filter = PointerLibraryFilter()
    @State private var galleryHeight: CGFloat = 320
    // Leave room for an always-visible native scrollbar and button focus rings
    // within the minimum 536 pt page. Fixed columns retain whole-pixel edges.
    private let columns = Array(repeating: GridItem(.fixed(164), spacing: Space.sm), count: 3)

    var body: some View {
        let library = PointerCatalog.entries
        let visible = filter.entries(from: library, pinned: Set(Preferences.pinnedStyles))
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("Pointer library").font(.headline)
                Spacer()
                Button("Make Your Own…") { model.startMakingHand() }
            }
            .gridProbe("library.heading", area: "library")
            Text("Enable pointers for quick selection. Pins choose toolbar favorites separately. Spotlight dims around the cursor; Presentation pointer is a telescoping rod.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .gridProbe("library.explanation", area: "library")
            if let message = model.pointerMessage {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pointer-library-error")
                    .gridProbe("library.error", area: "library")
            }
            if let message = model.handMessage {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            if let removed = model.removedHands.first {
                Button("Undo Remove \(removed.hand.name)") { model.undoHandRemoval() }
                    .help("Restore this hand, its gesture artwork and saved settings")
                    .accessibilityIdentifier("undo-remove-hand")
                    .gridProbe("library.undoRemoval", area: "library")
            }
            searchAndFilters
                .gridProbe("library.filters", area: "library")
            Text("Showing \(visible.count) of \(library.count) pointers")
                .font(.callout).foregroundStyle(.secondary)
                .accessibilityIdentifier("pointer-library-result-count")
                .gridProbe("library.count", area: "library")
            if !visible.contains(where: { $0.style == PointerStyle.saved }) {
                Text("Current pointer: \(PointerStyle.saved.title). Hidden by these filters.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .gridProbe("library.hiddenSelection", area: "library")
            }
            if visible.isEmpty {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Label("No matching pointers", systemImage: "magnifyingglass").font(.headline)
                    Text("Try another name or reset search and filters.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Reset Search and Filters") { filter = PointerLibraryFilter() }
                }
                .padding(Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("pointer-library-empty")
                .gridProbe("library.empty", area: "library")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: Space.sm) {
                        ForEach(visible, id: \.style) { entry in
                            PointerLibraryCell(entry: entry, model: model)
                        }
                    }
                    .padding(Space.xs)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: PointerGalleryHeight.self, value: proxy.size.height)
                    })
                }
                .frame(height: min(320, galleryHeight))
                .onPreferenceChange(PointerGalleryHeight.self) { galleryHeight = $0 }
                .accessibilityLabel("Pointer library results")
                .gridProbe("library.gallery", area: "library")
            }
        }
        .gridArea("library", inset: 0)
    }

    private var searchAndFilters: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                TextField("Search pointers", text: $filter.query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search pointers")
                    .help("Search pointer names. Search does not change your current pointer.")
                Button("Clear Search") { filter.query = "" }
                    .disabled(filter.query.isEmpty)
            }
            HStack(spacing: Space.md) {
                Toggle("Enabled", isOn: $filter.enabledOnly)
                    .accessibilityLabel("Show enabled pointers only")
                Toggle("Pinned", isOn: $filter.pinnedOnly)
                    .accessibilityLabel("Show pinned pointers only")
                Toggle("Custom", isOn: $filter.customOnly)
                    .accessibilityLabel("Show custom pointers only")
                Spacer(minLength: 0)
                Button("Reset Filters") {
                    filter.enabledOnly = false
                    filter.pinnedOnly = false
                    filter.customOnly = false
                }
                .disabled(!filter.hasFilters)
            }
            .toggleStyle(.checkbox)
            Text("Combine filters to narrow the library. Pinned pointers can be disabled.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PointerGalleryHeight: PreferenceKey {
    static let defaultValue: CGFloat = 320
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct PointerLibraryCell: View {
    let entry: PointerCatalog.Entry
    @ObservedObject var model: SettingsModel
    private var area: String { "pointer.\(entry.style.rawValue)" }
    private var selected: Bool { PointerStyle.saved == entry.style }
    private var pinned: Bool { Preferences.pinnedStyles.contains(entry.style) }

    private var statusSymbol: String {
        if !entry.available { return "photo.badge.exclamationmark" }
        if !entry.enabled { return "minus.circle" }
        return selected ? "checkmark.circle.fill" : "checkmark.circle"
    }

    private var status: String {
        if !entry.available { return "Image unavailable" }
        if !entry.enabled { return "Disabled" }
        return selected ? "Selected" : "Ready"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Group {
                    if entry.available, let icon = pointerIcon(entry.style) {
                        Image(nsImage: icon).resizable().interpolation(.high)
                    } else {
                        Image(systemName: "photo.badge.exclamationmark").resizable().scaledToFit()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
                Text(entry.style.title).font(.callout).lineLimit(1).help(entry.style.title)
            }
            .gridProbe("\(area).identity", area: area)
            Label(status, systemImage: statusSymbol).font(.caption).foregroundStyle(.secondary)
                .gridProbe("\(area).status", area: area)
            HStack(spacing: Space.xs) {
                Toggle("Enabled", isOn: Binding(get: { entry.enabled }, set: { model.setPointerEnabled($0, for: entry.style) }))
                    .toggleStyle(.checkbox).font(.callout)
                    .accessibilityLabel("Enable \(entry.style.title)")
                    .accessibilityIdentifier("pointer-enabled-\(entry.style.rawValue)")
                    .help("Enable \(entry.style.title) for quick selection. Toolbar pins are kept separately.")
                Spacer(minLength: 0)
                Button("Select") { model.selectPointer(entry.style) }
                    .controlSize(.small)
                    .disabled(!entry.selectable)
                    .accessibilityLabel("Select \(entry.style.title)")
                    .accessibilityValue(selected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .help("Select \(entry.style.title) without turning the pointer on")
            }
            .gridProbe("\(area).controls", area: area)
            Button { model.pin(entry.style) } label: {
                Label(pinned ? "Pinned" : "Not pinned", systemImage: pinned ? "pin.fill" : "pin")
            }
            .controlSize(.small)
            .accessibilityLabel("Toolbar pin for \(entry.style.title)")
            .accessibilityValue(pinned ? "Pinned" : "Not pinned")
            .help(pinned ? "Unpin \(entry.style.title) from the toolbar. Enabled stays unchanged."
                  : "Pin \(entry.style.title) to the toolbar. Enabled stays unchanged.")
            .gridProbe("\(area).pin", area: area)
            if entry.style.isCustom {
                Button("Remove Hand") { model.removeHand(entry.style) }
                    .controlSize(.small)
                    .accessibilityLabel("Remove \(entry.style.title)")
                    .help("Remove this hand from the library. Undo is available above the library.")
                    .gridProbe("\(area).remove", area: area)
            }
            if model.pointerErrorID == entry.style.rawValue, let message = model.pointerMessage {
                Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
                    .gridProbe("\(area).error", area: area)
            }
        }
        .padding(Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Space.sm).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: Space.sm).strokeBorder(selected ? Color.primary : Color.clear, lineWidth: 2))
        .gridArea(area, inset: Space.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(entry.style.title)
        .accessibilityValue("\(status). \(pinned ? "Pinned" : "Not pinned")")
        .contextMenu {
            Button(entry.enabled ? "Disable Pointer" : "Enable Pointer") { model.setPointerEnabled(!entry.enabled, for: entry.style) }
            Button("Select Pointer") { model.selectPointer(entry.style) }.disabled(!entry.selectable)
            Button(Preferences.pinnedStyles.contains(entry.style) ? "Unpin from Toolbar" : "Pin to Toolbar") { model.pin(entry.style) }
            if entry.style.isCustom {
                Divider()
                Button("Remove Hand") { model.removeHand(entry.style) }
            }
        }
    }
}

struct SelectedPointerDetails: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Label("Selected pointer: \(PointerStyle.saved.title)", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .gridProbe("selectedPointer.heading", area: "selectedPointer")
            PointerCustomization(style: PointerStyle.saved, model: model)
                .gridProbe("selectedPointer.customization", area: "selectedPointer")
            HandGestureSettings(model: model)
                .gridProbe("selectedPointer.gestures", area: "selectedPointer")
        }
        .gridArea("selectedPointer", inset: 0)
    }
}
