import Foundation

/// Browsing state only. Applying a filter never selects, enables or pins a pointer.
struct PointerLibraryFilter {
    var query = ""
    var enabledOnly = false
    var pinnedOnly = false
    var customOnly = false

    var hasFilters: Bool { enabledOnly || pinnedOnly || customOnly }
    var isActive: Bool { !query.isEmpty || hasFilters }

    func entries(from library: [PointerCatalog.Entry], pinned: Set<PointerStyle>) -> [PointerCatalog.Entry] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return library.filter { entry in
            (!enabledOnly || entry.enabled) &&
            (!pinnedOnly || pinned.contains(entry.style)) &&
            (!customOnly || entry.style.isCustom) &&
            (search.isEmpty || entry.style.title.localizedStandardContains(search) ||
                entry.style.rawValue.localizedStandardContains(search))
        }
    }
}
