import AppKit

/// App-owned pointer eligibility. Pins only choose toolbar favorites; they never
/// change this library or its stable built-in, custom, laser ordering.
enum PointerCatalog {
    struct Problem: Error {
        let code: String
        let message: String
    }

    struct Entry: Equatable {
        let style: PointerStyle
        let enabled: Bool
        let available: Bool
        var selectable: Bool { enabled && available }
    }

    static var entries: [Entry] {
        PointerStyle.allCases.map {
            Entry(style: $0, enabled: !Preferences.disabledPointerIDs.contains($0.rawValue),
                  available: $0.assetName.map(HandAsset.isAvailable) ?? true)
        }
    }

    /// All enabled, available choices, including every unpinned pointer.
    static var selectableStyles: [PointerStyle] { entries.filter(\.selectable).map(\.style) }

    /// Resolve one cycle against the current full catalog, never toolbar favorites.
    static func nextSelectable(after current: PointerStyle) throws -> PointerStyle {
        let choices = selectableStyles
        guard let first = choices.first else {
            throw Problem(code: "no-enabled-pointer", message: "Enable an available pointer in Settings > Pointers first.")
        }
        guard let index = choices.firstIndex(of: current) else { return first }
        return choices[(index + 1) % choices.count]
    }

    static var quickStyles: [PointerStyle] {
        let available = Set(selectableStyles)
        let pins = Preferences.pinnedStyles.filter { available.contains($0) }
        return pins.isEmpty ? Array(selectableStyles.prefix(1)) : pins
    }

    static func validateSelection(_ style: PointerStyle) throws {
        guard let entry = entries.first(where: { $0.style == style }) else {
            throw Problem(code: "unknown-style", message: "This pointer is no longer available. Refresh the pointer list.")
        }
        // Report missing images independently, even when also disabled.
        guard entry.available else {
            throw Problem(code: "missing-asset", message: "The image for this pointer is unavailable. Restore its image or choose another pointer.")
        }
        guard entry.enabled else {
            throw Problem(code: "disabled-style", message: "This pointer is disabled. Enable it in Settings > Pointers first.")
        }
    }

    static func setEnabled(_ enabled: Bool, for style: PointerStyle) throws {
        let library = entries
        guard library.contains(where: { $0.style == style }) else {
            throw Problem(code: "unknown-style", message: "This pointer is no longer available. Refresh the pointer list.")
        }
        var disabled = Preferences.disabledPointerIDs
        if enabled { disabled.remove(style.rawValue) } else { disabled.insert(style.rawValue) }
        let remaining = library.filter { $0.available && !disabled.contains($0.style.rawValue) }
        guard !remaining.isEmpty else {
            throw Problem(code: "last-enabled-pointer", message: "Keep at least one available pointer enabled.")
        }
        let selected = PointerStyle.saved
        Preferences.performBatch {
            Preferences.disabledPointerIDs = disabled
            if !remaining.contains(where: { $0.style == selected }) { PointerStyle.saved = remaining[0].style }
        }
    }

    /// Repair asset loss or malformed saved state without stealing selection when
    /// an image reappears. Laser is always available if no hand image can load.
    static func reconcile() {
        let library = entries
        let usable = library.filter(\.selectable)
        let fallback = usable.first ?? library.first(where: \.available)!
        let needsEnable = usable.isEmpty
        let needsSelection = !usable.contains(where: { $0.style.rawValue == PointerStyle.savedID })
        guard needsEnable || needsSelection else { return }
        Preferences.performBatch {
            if needsEnable {
                var disabled = Preferences.disabledPointerIDs
                disabled.remove(fallback.style.rawValue)
                Preferences.disabledPointerIDs = disabled
            }
            PointerStyle.saved = fallback.style
        }
    }
}
