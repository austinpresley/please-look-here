import SwiftUI

struct PointerLibrary: View {
    @ObservedObject var model: SettingsModel
    // Three 172 pt tiles plus two 8 pt gaps fit the minimum 536 pt page.
    // Fixed columns keep checkbox/text edges on whole pixels at every width.
    private let columns = Array(repeating: GridItem(.fixed(172), spacing: Space.sm), count: 3)

    var body: some View {
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
            LazyVGrid(columns: columns, alignment: .leading, spacing: Space.sm) {
                ForEach(PointerCatalog.entries, id: \.style) { entry in
                    PointerLibraryCell(entry: entry, model: model)
                }
            }
            .gridProbe("library.gallery", area: "library")
        }
        .gridArea("library", inset: 0)
    }
}

private struct PointerLibraryCell: View {
    let entry: PointerCatalog.Entry
    @ObservedObject var model: SettingsModel
    private var area: String { "pointer.\(entry.style.rawValue)" }

    private var status: String {
        if !entry.available { return "Image unavailable" }
        if !entry.enabled { return "Disabled" }
        return PointerStyle.saved == entry.style ? "Selected" : "Ready"
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
            Text(status).font(.caption).foregroundStyle(.secondary)
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
                    .help("Select \(entry.style.title) without turning the pointer on")
            }
            .gridProbe("\(area).controls", area: area)
            if model.pointerErrorID == entry.style.rawValue, let message = model.pointerMessage {
                Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
                    .gridProbe("\(area).error", area: area)
            }
        }
        .padding(Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Space.sm).fill(Color.primary.opacity(0.04)))
        .gridArea(area, inset: Space.sm)
        .contextMenu {
            Button(entry.enabled ? "Disable Pointer" : "Enable Pointer") { model.setPointerEnabled(!entry.enabled, for: entry.style) }
            Button("Select Pointer") { model.selectPointer(entry.style) }.disabled(!entry.selectable)
            Button(Preferences.pinnedStyles.contains(entry.style) ? "Unpin from Toolbar" : "Pin to Toolbar") { model.pin(entry.style) }
            if entry.style.isCustom {
                Divider()
                Button("Delete Hand") { model.removeHand(entry.style) }
            }
        }
    }
}
