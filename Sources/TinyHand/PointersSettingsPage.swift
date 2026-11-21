import AppKit
import SwiftUI

struct PointersPage: View {
    @ObservedObject var model: SettingsModel
    private var entries: [PointerCatalog.Entry] {
        model.libraryFilter.entries(from: PointerCatalog.entries, pinned: Set(Preferences.pinnedStyles))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(spacing: Space.sm) {
                TextField("Search pointers", text: $model.libraryFilter.query)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Search pointers")
                Text("\(entries.count)").font(.callout).monospacedDigit().foregroundStyle(.secondary)
                    .accessibilityLabel("\(entries.count) matching pointers").accessibilityIdentifier("pointer-library-result-count")
                Picker("Library filter", selection: $model.libraryFilter.category) {
                    ForEach(PointerLibraryFilter.Category.allCases, id: \.self) { category in
                        Image(systemName: category.symbol).tag(category).help(category.title).accessibilityLabel(category.title)
                    }
                }.labelsHidden().pickerStyle(.segmented).frame(width: 112).help("All / Favorites / Hidden")
                Button { model.startMakingHand() } label: { Label("New Hand…", systemImage: "plus") }
                    .help("Add a new custom hand")
            }.gridProbe("pointers.toolbar", area: "pointers")
            HStack(alignment: .top, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.md) {
                    PointerFavoritesCard(model: model)
                    PointerLibrary(model: model)
                }.frame(maxWidth: .infinity, alignment: .leading)
                PointerInspector(model: model).frame(width: 296)
            }.gridProbe("pointers.columns", area: "pointers")
        }.gridArea("pointers", inset: 0)
    }
}

struct PointerArtwork: View {
    let style: PointerStyle
    var side: CGFloat = 40
    var body: some View {
        Group {
            if style.assetName.map(HandAsset.isAvailable) ?? true, let image = pointerIcon(style) { Image(nsImage: image).resizable().scaledToFit() }
            else { Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.secondary) }
        }.frame(width: side, height: side).accessibilityHidden(true)
    }
}

struct PointerStar: View {
    let style: PointerStyle
    @ObservedObject var model: SettingsModel
    private var starred: Bool { Preferences.pinnedStyles.contains(style) }
    var body: some View {
        Button { model.pin(style) } label: {
            Image(systemName: starred ? "star.fill" : "star")
                .foregroundStyle(starred ? Color.orange : Color.secondary).frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel("\(starred ? "Unfavorite" : "Favorite") \(style.title)")
            .accessibilityValue(starred ? "In toolbar" : "Not in toolbar")
            .help(starred ? "Remove from toolbar favorites. Wheel direction stays." : "Add to toolbar favorites, up to 8")
            .accessibilityIdentifier("pointer.star.\(style.rawValue)")
    }
}

struct PointerFavoriteActions: View {
    let style: PointerStyle
    @ObservedObject var model: SettingsModel
    var body: some View {
        Button("Move Left") { model.movePin(style, direction: .left) }.disabled(!model.canMovePin(style, direction: .left))
        Button("Move Right") { model.movePin(style, direction: .right) }.disabled(!model.canMovePin(style, direction: .right))
        Menu("Wheel direction") {
            ForEach(0..<6, id: \.self) { slot in
                let id = Preferences.quickControlFavorites[slot]
                let selected = id == style.rawValue
                let occupant = PointerStyle(rawValue: id)?.title ?? "Unavailable (\(id))"
                Button {
                    _ = Preferences.assignQuickControlFavorite(style.rawValue, to: slot); model.refresh()
                } label: {
                    Text("\(selected ? "✓ " : "")\(PointerBrowserModel.destinations[slot])\(selected ? " · Current" : " · \(Preferences.quickControlFavorites.contains(style.rawValue) ? "Swap with" : "Replace") \(occupant)")")
                }
            }
        }
        Divider()
        Button(Preferences.pinnedStyles.contains(style) ? "Unfavorite · Wheel slot stays" : "Favorite in Toolbar") { model.pin(style) }
    }
}

private struct PointerFavoritesCard: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                VStack(alignment: .leading, spacing: Space.sm) {
                    HStack(spacing: Space.xs) {
                        ForEach(Preferences.pinnedStyles, id: \.self) { style in
                            Button { model.inspectPointer(style) } label: { PointerArtwork(style: style, side: 28) }
                                .buttonStyle(.plain).help(style.title).accessibilityLabel(PointerCatalog.entries.first(where: { $0.style == style })?.selectable == true ? "Use and inspect favorite \(style.title)" : "Inspect favorite \(style.title)")
                                .contextMenu { PointerFavoriteActions(style: style, model: model) }
                        }
                    }
                    Label("\(Preferences.pinnedStyles.count) of 8", systemImage: "star.fill")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                WheelDirectionMap(model: model)
            }
            if let message = model.pinMessage { Text(message).font(.callout).foregroundStyle(.secondary) }
        }.padding(Space.md)
            .background(RoundedRectangle(cornerRadius: Space.md).fill(Color.primary.opacity(0.045)))
    }
}

private struct WheelDirectionMap: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        Grid(horizontalSpacing: Space.xs, verticalSpacing: 0) {
            GridRow { Image(nsImage: UsabilityGlyph.library.image).resizable().frame(width: 16, height: 16).help("Northwest: All pointers"); slot(0); slot(1) }
            GridRow { slot(5); Image(nsImage: UsabilityGlyph.wheel.image).resizable().frame(width: 16, height: 16).help("Quick controls keeps its six learned directions"); slot(2) }
            GridRow { slot(4); Image(systemName: "arrow.uturn.backward").help("South: Back"); slot(3) }
        }.frame(width: 88).accessibilityElement(children: .contain).accessibilityLabel("Quick controls directions")
    }
    private func slot(_ index: Int) -> some View {
        let id = Preferences.quickControlFavorites[index]
        let entry = PointerCatalog.entries.first { $0.style.rawValue == id }
        return Menu {
            Text("\(PointerBrowserModel.destinations[index]): \(entry?.style.title ?? id)")
            if entry?.selectable != true { Text(entry == nil || entry?.available == false ? "Artwork unavailable. Saved slot retained." : "Hidden in lists. Saved slot retained.") }
            ForEach(PointerCatalog.entries, id: \.style) { choice in
                Button("\(choice.style.rawValue == id ? "✓ " : "")\(choice.style.title)") {
                    _ = Preferences.assignQuickControlFavorite(choice.style.rawValue, to: index); model.refresh()
                }
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if let entry, entry.available { Image(nsImage: fittedPointerImage(pointerIcon(entry.style), side: 24)) }
                else { Image(systemName: "photo.badge.exclamationmark").frame(width: 24, height: 24) }
                if entry?.selectable == false { Image(systemName: "eye.slash.fill").font(.system(size: 10)) }
            }
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 24, height: 24)
            .accessibilityLabel("\(PointerBrowserModel.destinations[index]): \(entry?.style.title ?? id), \(entry?.selectable == true ? "available" : "unavailable or hidden")")
            .help("\(PointerBrowserModel.destinations[index]): \(entry?.style.title ?? id). Assigning an existing wheel pointer swaps slots.")
    }
}
