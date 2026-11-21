import Foundation

/// Browsing state only. Applying a filter never selects, enables or pins a pointer.
struct PointerLibraryFilter {
    enum Category: String, CaseIterable {
        case all, favorites, hidden
        var symbol: String { switch self { case .all: return "square.grid.2x2"; case .favorites: return "star"; case .hidden: return "eye.slash" } }
        var title: String { rawValue.capitalized }
    }
    var category: Category = .all
    var query = ""
    var enabledOnly = false
    var pinnedOnly = false
    var customOnly = false

    var hasFilters: Bool { category != .all || enabledOnly || pinnedOnly || customOnly }
    var isActive: Bool { !query.isEmpty || hasFilters }

    func entries(from library: [PointerCatalog.Entry], pinned: Set<PointerStyle>) -> [PointerCatalog.Entry] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return library.filter { entry in
            (category != .favorites || pinned.contains(entry.style)) &&
            (category != .hidden || !entry.enabled || !entry.available) &&
            (!enabledOnly || entry.enabled) &&
            (!pinnedOnly || pinned.contains(entry.style)) &&
            (!customOnly || entry.style.isCustom) &&
            (search.isEmpty || entry.style.title.localizedStandardContains(search) ||
                entry.style.rawValue.localizedStandardContains(search))
        }
    }
}
