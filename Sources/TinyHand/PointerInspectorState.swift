import Foundation

/// Transient editing scope. Selecting any library entry explicitly leaves Defaults.
struct PointerInspectorState {
    enum Scope: String, CaseIterable { case this, defaults }
    var style: PointerStyle = .saved
    var scope: Scope = .this
    mutating func select(_ style: PointerStyle) { self.style = style; scope = .this }
    var isDefaults: Bool { scope == .defaults }
    var title: String { isDefaults ? "Pointer defaults" : style.title }
    var handControls: Bool { isDefaults || style.assetName != nil }
    var gestures: Bool { !isDefaults && style.assetName != nil }
    var pointerActions: Bool { !isDefaults }
    var sizeLabel: String { isDefaults ? "Default size" : PointerConfigurationPolicy(style.rawValue).sizeLabel }
    var preview: PointerPreviewConfiguration {
        if isDefaults { var sample = PointerPreviewConfiguration.sharedDefaults; sample.referenceHeight = 320; return sample }
        let value = Preferences.pointerConfiguration(for: style.rawValue)
        return PointerPreviewConfiguration(style: style, size: value.size, shadow: value.shadow,
            shadowStyle: value.shadowStyle, motion: Preferences.pointerMotion, tapSwing: Preferences.tapSwing, referenceHeight: 320, artworkSignature: style.assetName.map(HandAsset.imageSignature) ?? "")
    }
}

/// Favorites adopt the existing toolbar store without rewriting either legacy layout.
/// Six wheel assignments remain a separate learned layout, including absent IDs.
struct FavoriteLibraryConfiguration {
    let toolbarIDs: [String]
    let wheelIDs: [String]
    static func migrated(from storage: UserDefaults) -> Self {
        Self(toolbarIDs: storage.stringArray(forKey: "pinnedStyles") ?? PointerStyle.defaultPinned.map(\.rawValue),
             wheelIDs: RadialFavorites.load(from: storage))
    }
}

/// Each supported override resets independently, including the non-hand menu.
enum PointerOverrideField {
    case size, shadow, shadowStyle, soundEnabled, sound
    func reset(_ value: inout PointerOverride) {
        switch self {
        case .size: value.size = nil
        case .shadow: value.shadow = nil
        case .shadowStyle: value.shadowStyle = nil
        case .soundEnabled: value.soundEnabled = nil
        case .sound: value.sound = nil
        }
    }
}
extension SettingsModel {
    func editPointer(_ style: PointerStyle, _ change: (inout PointerOverride) -> Void) {
        do { try Preferences.updatePointer(style.rawValue, change); pointerMessage = nil }
        catch { pointerMessage = error.localizedDescription }
        refresh()
    }
    func resetPointer(_ style: PointerStyle, field: PointerOverrideField) { editPointer(style) { field.reset(&$0) } }
}
