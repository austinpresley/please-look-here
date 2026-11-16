import Foundation
import CoreFoundation
import ImageIO

struct PresentationArchiveError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Scalars only. The allowlist below is also the entire preference write boundary.
enum PresentationValue: Codable, Equatable {
    case bool(Bool), number(Double), string(String)
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let bool = try? value.decode(Bool.self) { self = .bool(bool) }
        else if let number = try? value.decode(Double.self) { self = .number(number) }
        else { self = .string(try value.decode(String.self)) }
    }
    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .bool(let bool): try value.encode(bool)
        case .number(let number): try value.encode(number)
        case .string(let string): try value.encode(string)
        }
    }
    var object: Any {
        switch self { case .bool(let v): return v; case .number(let v): return v; case .string(let v): return v }
    }
}

struct PresentationSettingsSchema {
    enum Rule {
        case bool(Bool), number(Double, ClosedRange<Double>), choice(String, [String])
        var initial: PresentationValue {
            switch self {
            case .bool(let v): return .bool(v)
            case .number(let v, _): return .number(v)
            case .choice(let v, _): return .string(v)
            }
        }
        func accepts(_ value: PresentationValue) -> Bool {
            switch (self, value) {
            case (.bool, .bool): return true
            case (.number(_, let range), .number(let v)): return v.isFinite && range.contains(v)
            case (.choice(_, let choices), .string(let v)): return choices.contains(v)
            default: return false
            }
        }
    }
    static let rules: [String: Rule] = [
        "pointerSize": .number(0.13, 0.04...0.20), "showShadow": .bool(true),
        "shadowStyle": .choice("original", PointerShadowStyle.allCases.map(\.rawValue)),
        "pointerMotion": .choice("original", PointerMotion.allCases.map(\.rawValue)),
        "theme": .choice("system", AppTheme.allCases.map(\.rawValue)),
        "showToolbar": .bool(true), "showInkButton": .bool(true), "interactKeepsHand": .bool(true),
        "drawingTool": .choice("pen", DrawingTool.allCases.map(\.rawValue)),
        "inkChoice": .choice("match", InkChoice.allCases.map(\.rawValue)),
        "strokeWidth": .number(6, 2...20), "inkOpacity": .number(1, 0.1...1),
        "strokeSmoothing": .number(2, 0...3), "fadeSeconds": .number(3, 0...60),
        "inkFadeStyle": .choice("wholeLine", InkFadeStyle.allCases.map(\.rawValue)),
        "trailDelay": .number(1, 0.2...3), "trailSpeed": .number(240, 40...600),
        "magnifierZoom": .number(3, 1.5...6), "magnifierDiameter": .number(240, 160...480),
        "tapSwing": .number(0, 0...2), "sound.hands": .bool(true), "sound.laser": .bool(false),
        "tapSound": .choice("thock", TapSoundChoice.allCases.map(\.rawValue)),
        "sound.volume": .number(1, 0...1), "sound.muted": .bool(false),
        "capture.copy": .bool(true), "capture.save": .bool(true)
    ]
    static let titles: [String: String] = [
        "pointerSize": "Pointer size", "showShadow": "Shadow", "shadowStyle": "Shadow style",
        "pointerMotion": "Pointer motion", "theme": "Appearance", "showToolbar": "Show toolbar",
        "showInkButton": "Show ink button", "interactKeepsHand": "Keep hand visible while interacting",
        "drawingTool": "Drawing tool", "inkChoice": "Ink color", "strokeWidth": "Stroke width",
        "inkOpacity": "Ink opacity", "strokeSmoothing": "Stroke smoothing", "fadeSeconds": "Fade delay",
        "inkFadeStyle": "Ink fading", "trailDelay": "Trail delay", "trailSpeed": "Trail speed",
        "magnifierZoom": "Magnification", "magnifierDiameter": "Magnifier diameter", "tapSwing": "Tap swing",
        "sound.hands": "Default pointer sound", "sound.laser": "Legacy laser sound",
        "tapSound": "Default tap sound", "sound.volume": "App volume", "sound.muted": "Mute all sounds",
        "capture.copy": "Copy screenshots", "capture.save": "Save screenshots"
    ]
    static func display(_ value: PresentationValue) -> String {
        switch value {
        case .bool(let v): return v ? "On" : "Off"
        case .number(let v): return String(format: "%.3g", v)
        case .string(let v): return v
        }
    }

    static func capture(_ storage: UserDefaults) throws -> [String: PresentationValue] {
        var values: [String: PresentationValue] = [:]
        for (key, rule) in rules {
            guard let object = storage.object(forKey: key) else { values[key] = rule.initial; continue }
            if let n = object as? NSNumber {
                values[key] = CFGetTypeID(n) == CFBooleanGetTypeID() ? .bool(n.boolValue) : .number(n.doubleValue)
            } else if let s = object as? String { values[key] = .string(s) }
            else { throw PresentationArchiveError(message: "Unable to read \(key). Repair this setting before saving a setup.") }
        }
        // Materialize the legacy fade mode exactly as Preferences does.
        if storage.object(forKey: "inkFadeStyle") == nil, case .number(let seconds) = values["fadeSeconds"], seconds <= 0 {
            values["inkFadeStyle"] = .string("permanent")
        }
        try validate(values)
        return values
    }
    static func validate(_ values: [String: PresentationValue]) throws {
        guard Set(values.keys) == Set(rules.keys), values.allSatisfy({ rules[$0.key]?.accepts($0.value) == true }),
              values["strokeSmoothing"].map({ if case .number(let v) = $0 { return v.rounded() == v }; return false }) == true,
              values["capture.copy"] == .bool(true) || values["capture.save"] == .bool(true) else {
            throw PresentationArchiveError(message: "Invalid setup settings. Choose a complete version 1 export with supported values.")
        }
    }
}

struct PresentationSetup: Codable, Equatable {
    var selectedID: String
    var pinnedIDs: [String]
    var disabledIDs: [String]
    var settings: [String: PresentationValue]
    /// Encoded through the validated public override API, including absent IDs.
    var pointerOverrides: Data

    static func capture(_ storage: UserDefaults) throws -> Self {
        let value = Self(selectedID: storage.string(forKey: "pointerStyle") ?? "lavender",
            pinnedIDs: storage.stringArray(forKey: "pinnedStyles") ?? PointerStyle.defaultPinned.map(\.rawValue),
            disabledIDs: storage.stringArray(forKey: "disabledPointerIDs") ?? [],
            settings: try PresentationSettingsSchema.capture(storage),
            pointerOverrides: try PointerConfigurationDocument.load(from: storage).encoded())
        try value.validate()
        return value
    }
    func validate() throws {
        try PresentationSettingsSchema.validate(settings)
        let all = pinnedIDs + disabledIDs + [selectedID]
        guard all.allSatisfy(PointerConfigurationDocument.validID), pinnedIDs.count <= Preferences.maxPinned,
              !pinnedIDs.isEmpty, disabledIDs.count <= 4096,
              Set(pinnedIDs).count == pinnedIDs.count, Set(disabledIDs).count == disabledIDs.count,
              !disabledIDs.contains(selectedID) else {
            throw PresentationArchiveError(message: "Invalid pointer selection, enabled list or toolbar pins. Keep the selected pointer enabled.")
        }
        _ = try PointerConfigurationDocument.decode(pointerOverrides)
    }
    var preferences: [String: Any] {
        var values = settings.mapValues(\.object)
        values["pointerStyle"] = selectedID
        values["pinnedStyles"] = pinnedIDs
        values["disabledPointerIDs"] = disabledIDs
        values[PointerConfigurationDocument.storageKey] = pointerOverrides
        return values
    }
    static var preferenceKeys: Set<String> {
        Set(PresentationSettingsSchema.rules.keys).union(["pointerStyle", "pinnedStyles", "disabledPointerIDs", PointerConfigurationDocument.storageKey])
    }
}

struct NamedPresentationPreset: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var setup: PresentationSetup
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.utf8.count <= 160,
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw PresentationArchiveError(message: "Give the preset a name of 160 bytes or fewer without control characters.")
        }
        try setup.validate()
    }
}

struct PortablePresentationArchive: Codable, Equatable {
    static let maximumBytes = 100_000_000
    var format = "look-here-please-portable"
    var version = 1
    var setup: PresentationSetup
    var presets: [NamedPresentationPreset]
    var hands: [CustomHand]
    /// Canonical filenames only. Data uses JSON's standard base64 encoding.
    var artwork: [String: Data]

    static var builtInHandIDs: Set<String> { Set(PointerStyle.builtInHands.map(\.rawValue)) }
    static func validArtworkPath(_ path: String, customIDs: Set<String>) -> Bool {
        if path.hasSuffix(".png"), customIDs.contains(String(path.dropLast(4))) { return true }
        for id in customIDs.union(builtInHandIDs) {
            for slot in ["first", "second"] where path == "Gestures/\(id)-\(slot).png" { return true }
        }
        return false
    }
    static func validatePresets(_ presets: [NamedPresentationPreset]) throws {
        guard presets.count <= 100, Set(presets.map(\.id)).count == presets.count,
              Set(presets.map { $0.name.lowercased() }).count == presets.count else {
            throw PresentationArchiveError(message: "Keep at most 100 presets with unique names and IDs.")
        }
        for preset in presets { try preset.validate() }
    }
    func validate() throws {
        guard format == "look-here-please-portable", version == 1, hands.count <= 256,
              Set(hands.map { $0.id.lowercased() }).count == hands.count else {
            throw PresentationArchiveError(message: "Unsupported or invalid backup. Choose a version 1 Look Here Please backup.")
        }
        try setup.validate()
        try Self.validatePresets(presets)
        for hand in hands {
            guard HandRecoveryStore.validID(hand.id), hand.id.utf8.count <= 128,
                  !hand.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, hand.name.utf8.count <= 160,
                  !hand.name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }), hand.ink <= 0xffffff else {
                throw PresentationArchiveError(message: "Invalid custom hand identity, name or ink color.")
            }
        }
        let ids = Set(hands.map(\.id))
        guard artwork.count <= 840, Set(artwork.keys.map { $0.lowercased() }).count == artwork.count, artwork.values.reduce(0, { $0 + $1.count }) <= 64_000_000,
              hands.allSatisfy({ artwork["\($0.id).png"] != nil }) else {
            throw PresentationArchiveError(message: "The backup is too large or is missing custom hand artwork.")
        }
        var dimensions: [String: [Int]] = [:]
        for (path, data) in artwork {
            guard Self.validArtworkPath(path, customIDs: ids), data.count <= 8_000_000, !data.isEmpty,
                  let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  CGImageSourceGetType(source) as String? == "public.png", CGImageSourceGetCount(source) == 1,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 8192, height <= 8192, width * height <= 16_777_216,
                  let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else {
                throw PresentationArchiveError(message: "Invalid or oversized PNG artwork at \(path.prefix(180)). Nothing was imported.")
            }
            if !path.hasPrefix("Gestures/"), !HandAsset.isUsablePointerArtwork(image) {
                throw PresentationArchiveError(message: "Custom hand artwork at \(path) has no usable hand and stick geometry.")
            }
            if path.hasPrefix("Gestures/"), Self.builtInHandIDs.contains(where: { path == "Gestures/\($0)-first.png" || path == "Gestures/\($0)-second.png" }),
               [width, height] != [1024, 1536] {
                throw PresentationArchiveError(message: "Version 1 built-in gesture artwork must use the original 1024 × 1536 canvas.")
            }
            dimensions[path] = [width, height]
        }
        for hand in hands {
            for slot in ["first", "second"] {
                if let gesture = dimensions["Gestures/\(hand.id)-\(slot).png"], gesture != dimensions["\(hand.id).png"] {
                    throw PresentationArchiveError(message: "Gesture artwork must match its custom hand dimensions.")
                }
            }
        }
    }
    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw PresentationArchiveError(message: "The backup exceeds 100 MB.") }
        return data
    }
    static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw PresentationArchiveError(message: "The backup exceeds 100 MB.") }
        // Reject unknown fields at every archive-owned object, including a nested
        // shortcut, startup or path field that an older reader might ignore.
        let json = try JSONSerialization.jsonObject(with: data)
        try exact(json, keys: ["format", "version", "setup", "presets", "hands", "artwork"])
        guard let root = json as? [String: Any], let presets = root["presets"] as? [Any],
              let hands = root["hands"] as? [Any] else { throw PresentationArchiveError(message: "Invalid backup structure.") }
        try checkSetup(root["setup"] as Any)
        for preset in presets { try checkPreset(preset) }
        for hand in hands { try exact(hand, keys: ["id", "name", "ink"]) }
        let archive = try JSONDecoder().decode(Self.self, from: data)
        try archive.validate()
        return archive
    }
    static func checkPreset(_ value: Any) throws {
        try exact(value, keys: ["id", "name", "setup"])
        try checkSetup((value as? [String: Any])?["setup"] as Any)
    }
    private static func checkSetup(_ object: Any) throws {
        try exact(object, keys: ["selectedID", "pinnedIDs", "disabledIDs", "settings", "pointerOverrides"])
    }
    private static func exact(_ value: Any, keys: Set<String>) throws {
        guard let object = value as? [String: Any], Set(object.keys) == keys else {
            throw PresentationArchiveError(message: "Unknown or missing backup fields. Choose a supported version 1 export.")
        }
    }
}
