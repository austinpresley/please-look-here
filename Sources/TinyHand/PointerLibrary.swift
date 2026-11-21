import SwiftUI

struct PointerLibrary: View {
    @ObservedObject var model: SettingsModel
    private let columns = [GridItem(.adaptive(minimum: 80), spacing: Space.sm)]
    var body: some View {
        let visible = model.libraryFilter.entries(from: PointerCatalog.entries, pinned: Set(Preferences.pinnedStyles))
        VStack(alignment: .leading, spacing: Space.sm) {
            if let message = model.pointerMessage { Text(message).font(.callout).foregroundStyle(.secondary) }
            if let message = model.handMessage { Text(message).font(.callout).foregroundStyle(.secondary) }
            if let receipt = model.removedHands.first {
                Button("Undo Remove \(receipt.hand.name)") { model.undoHandRemoval() }.accessibilityIdentifier("undo-remove-hand")
            }
            if visible.isEmpty {
                Label("No matching pointers", systemImage: "magnifyingglass").foregroundStyle(.secondary)
                Button("Show All") { model.libraryFilter = PointerLibraryFilter() }
            }
            LazyVGrid(columns: columns, spacing: Space.sm) {
                ForEach(visible, id: \.style) { entry in
                    VStack(spacing: 0) {
                        HStack { Spacer(minLength: 0); PointerStar(style: entry.style, model: model) }
                        Button { model.inspectPointer(entry.style) } label: {
                            VStack(spacing: Space.xs) {
                                PointerArtwork(style: entry.style, side: 48).opacity(entry.enabled ? 1 : 0.4)
                                Text(entry.style.title).font(.system(size: 11)).lineLimit(2).multilineTextAlignment(.center).frame(minHeight: 28)
                                if !entry.available { Label("Missing", systemImage: "photo.badge.exclamationmark").font(.system(size: 10)) }
                                else if !entry.enabled { Label("Hidden", systemImage: "eye.slash").font(.system(size: 10)) }
                            }.frame(maxWidth: .infinity).padding([.horizontal, .bottom], Space.sm).contentShape(Rectangle())
                        }.buttonStyle(.plain).help(entry.selectable ? "Use and inspect \(entry.style.title)" : "Inspect \(entry.style.title). Hidden or missing artwork.")
                            .accessibilityLabel(entry.selectable ? "Use and inspect \(entry.style.title)" : "Inspect \(entry.style.title)")
                            .accessibilityValue("\(entry.enabled ? "Visible" : "Hidden"). \(entry.available ? "Artwork available" : "Artwork missing")")
                    }
                    .background(RoundedRectangle(cornerRadius: Space.sm).fill(Color.primary.opacity(0.045)))
                    .overlay(RoundedRectangle(cornerRadius: Space.sm).strokeBorder(model.pointerInspector.style == entry.style && !model.pointerInspector.isDefaults ? Color.accentColor : .clear, lineWidth: 2))
                    .contextMenu {
                        PointerFavoriteActions(style: entry.style, model: model)
                        Button(entry.enabled ? "Hide from Lists" : "Show in Lists") { model.setPointerEnabled(!entry.enabled, for: entry.style) }
                    }
                }
            }
        }.gridArea("library", inset: 0)
    }
}
