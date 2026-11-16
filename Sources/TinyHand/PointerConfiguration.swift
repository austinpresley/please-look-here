import Foundation
import CoreFoundation

/// Nil inherits just this field. IDs deliberately do not depend on catalog membership:
/// unplugged, disabled and recoverable custom hands keep their configuration.
struct PointerOverride: Codable, Equatable {
    var size: Double?
    var shadow: Bool?
    var shadowStyle: PointerShadowStyle?
    var soundEnabled: Bool?
    var sound: TapSoundChoice?

    var isEmpty: Bool { self == PointerOverride() }
    static let fields: Set<String> = ["size", "shadow", "shadowStyle", "soundEnabled", "sound"]

    func validate(for id: String) throws {
        guard PointerConfigurationDocument.validID(id) else { throw PointerConfigurationError.invalid("Invalid pointer ID.") }
        if let size, !size.isFinite || !(0.04...0.20).contains(size) {
            throw PointerConfigurationError.invalid("Pointer size must be between 0.04 and 0.20.")
        }
        if !PointerConfigurationPolicy(id).supportsShadow && (shadow != nil || shadowStyle != nil) {
            throw PointerConfigurationError.invalid("This pointer has no configurable shadow.")
        }
        if !PointerConfigurationPolicy(id).supportsShadowStyle && shadowStyle != nil {
            throw PointerConfigurationError.invalid("Shadow style applies only to hands.")
        }
    }
}

enum PointerConfigurationError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

struct PointerConfigurationPolicy {
    let id: String
    init(_ id: String) { self.id = id }
    var supportsShadow: Bool { id != "laser" && id != "spotlight" }
    var supportsShadowStyle: Bool { supportsShadow && id != "presentation" }
    var sizeLabel: String {
        switch id {
        case "spotlight": return "Aperture size"
        case "presentation": return "Rod thickness"
        case "laser": return "Dot size"
        default: return "Hand size"
        }
    }
}

struct EffectivePointerConfiguration: Equatable {
    let size: Double
    let shadow: Bool
    let shadowStyle: PointerShadowStyle
    let soundEnabled: Bool
    let sound: TapSoundChoice

    var state: [String: Any] {
        ["size": size, "shadow": shadow, "shadowStyle": shadowStyle.rawValue,
         "soundEnabled": soundEnabled, "sound": sound.rawValue]
    }
}

/// Small portable archive. Decode/validate before replacing saved data. Unknown
/// versions, keys, enum values, wrong JSON types and inapplicable fields fail closed.
struct PointerConfigurationDocument: Codable, Equatable {
    static let storageKey = "pointerOverrides.v1"
    var version = 1
    var pointers: [String: PointerOverride] = [:]

    static func validID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 128 && id.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }

    func validate() throws {
        guard version == 1 else { throw PointerConfigurationError.invalid("Unsupported pointer settings version. Update Look Here Please before importing.") }
        guard pointers.count <= 4096 else { throw PointerConfigurationError.invalid("Too many pointer settings.") }
        for (id, override) in pointers { try override.validate(for: id) }
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 2_000_000,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(json.keys) == ["version", "pointers"],
              let version = json["version"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(),
              version.doubleValue == 1,
              let entries = json["pointers"] as? [String: Any] else {
            throw PointerConfigurationError.invalid("Invalid pointer settings archive. Choose a version 1 export.")
        }
        for value in entries.values { _ = try decodeOverride(value) }
        let document = try JSONDecoder().decode(Self.self, from: data)
        try document.validate()
        return document
    }

    static func decodeOverride(_ value: Any) throws -> PointerOverride {
        guard let fields = value as? [String: Any], Set(fields.keys).isSubset(of: PointerOverride.fields) else {
            throw PointerConfigurationError.invalid("Unknown pointer setting. Use size, shadow, shadowStyle, soundEnabled or sound.")
        }
        for key in ["shadow", "soundEnabled"] {
            if let value = fields[key], !(value is NSNull) {
                guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
                    throw PointerConfigurationError.invalid("\(key) must be a boolean or null to inherit.")
                }
            }
        }
        if let value = fields["size"], !(value is NSNull) {
            guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else {
                throw PointerConfigurationError.invalid("Size must be a finite number or null to inherit.")
            }
        }
        return try JSONDecoder().decode(PointerOverride.self, from: JSONSerialization.data(withJSONObject: fields))
    }

    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Migration is lazy and read-only until a validated edit. The legacy laser
    /// flag was independent of hands; preserve it as an explicit enabled override.
    static func migrated(from storage: UserDefaults) -> Self {
        Self(pointers: ["laser": PointerOverride(soundEnabled: storage.object(forKey: "sound.laser") as? Bool ?? false)])
    }

    static func load(from storage: UserDefaults) throws -> Self {
        guard storage.object(forKey: storageKey) != nil else { return migrated(from: storage) }
        guard let data = storage.data(forKey: storageKey) else {
            throw PointerConfigurationError.invalid("Unable to read pointer settings. Restore a valid export before editing.")
        }
        return try decode(data)
    }

    func effective(for id: String, defaults: EffectivePointerConfiguration) -> EffectivePointerConfiguration {
        let value = pointers[id] ?? PointerOverride(), policy = PointerConfigurationPolicy(id)
        return EffectivePointerConfiguration(size: value.size ?? defaults.size,
            shadow: policy.supportsShadow && (value.shadow ?? defaults.shadow),
            shadowStyle: policy.supportsShadowStyle ? value.shadowStyle ?? defaults.shadowStyle : .original,
            soundEnabled: value.soundEnabled ?? defaults.soundEnabled, sound: value.sound ?? defaults.sound)
    }

    /// Replacement of one pointer is also the deletion recovery hook. Export
    /// `pointers[id]` before removal; restore it with this API, even if absent.
    mutating func replace(_ override: PointerOverride?, for id: String) throws {
        guard Self.validID(id) else { throw PointerConfigurationError.invalid("Invalid pointer ID.") }
        try override?.validate(for: id)
        pointers[id] = override?.isEmpty == true ? nil : override
    }

    /// Patch keeps unspecified fields, and JSON null restores inheritance per field.
    mutating func patch(_ fields: [String: Any], for id: String) throws {
        _ = try Self.decodeOverride(fields)
        let old = pointers[id] ?? PointerOverride()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
        json.merge(fields) { _, new in new }
        try replace(Self.decodeOverride(json), for: id)
    }

    func applying(_ patches: Any) throws -> Self {
        guard let patches = patches as? [String: Any], patches.count <= 4096 else {
            throw PointerConfigurationError.invalid("Pointer overrides must be an object keyed by pointer ID.")
        }
        var result = self
        for (id, fields) in patches {
            if fields is NSNull { try result.replace(nil, for: id) }
            else if let fields = fields as? [String: Any] { try result.patch(fields, for: id) }
            else { throw PointerConfigurationError.invalid("Each pointer override must be an object or null to use all defaults.") }
        }
        try result.validate()
        return result
    }
}

extension Preferences {
    static var pointerDefaults: EffectivePointerConfiguration {
        EffectivePointerConfiguration(size: Double(pointerSize), shadow: showShadow,
            shadowStyle: shadowStyle, soundEnabled: handSound, sound: tapSound)
    }

    static func pointerConfiguration(for id: String) -> EffectivePointerConfiguration {
        // Never overwrite an unreadable archive while reading effective settings.
        let document = (try? PointerConfigurationDocument.load(from: storage)) ?? .migrated(from: storage)
        return document.effective(for: id, defaults: pointerDefaults)
    }

    static func savePointerConfigurations(_ document: PointerConfigurationDocument) throws {
        let data = try document.encoded()
        storage.set(data, forKey: PointerConfigurationDocument.storageKey)
        notifyPointerConfigurationChanged()
    }

    static func updatePointer(_ id: String, _ changes: (inout PointerOverride) -> Void) throws {
        var document = try PointerConfigurationDocument.load(from: storage)
        var override = document.pointers[id] ?? PointerOverride()
        changes(&override)
        try document.replace(override, for: id)
        try savePointerConfigurations(document)
    }

    static func pointerConfigurationState(for id: String) -> [String: Any] {
        let loaded = try? PointerConfigurationDocument.load(from: storage)
        let override = loaded?.pointers[id] ?? PointerOverride()
        let fields = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(override))) as? [String: Any] ?? [:]
        return ["effective": pointerConfiguration(for: id).state, "overrides": fields,
                "customized": !override.isEmpty, "sizeLabel": PointerConfigurationPolicy(id).sizeLabel,
                "supportsShadow": PointerConfigurationPolicy(id).supportsShadow,
                "supportsShadowStyle": PointerConfigurationPolicy(id).supportsShadowStyle,
                "readable": loaded != nil]
    }
}
