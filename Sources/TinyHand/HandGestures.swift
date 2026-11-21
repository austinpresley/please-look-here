import AppKit
import Carbon.HIToolbox

enum HandGestureSlot: String, CaseIterable {
    case first, second
    var title: String { self == .first ? "Gesture 1" : "Gesture 2" }
    var stockTitle: String { self == .first ? "OK" : "Shaka" }
    var assetName: String { self == .first ? "gesture_ok" : "gesture_shaka" }
    var poseName: String { self == .first ? "ok" : "shaka" }
    var action: PresentationAction { self == .first ? .gesture1 : .gesture2 }
}

/// Poses remain separate from pointer IDs, pins and enabled-pointer cycling.
enum HandGestureCatalog {
    private struct Cached { let signature: String; let image: CGImage }
    private static var cache: [String: Cached] = [:]
    static func forget() { cache.removeAll() }
    static func url(for slot: HandGestureSlot, style: PointerStyle) -> URL {
        CustomHands.directory.appendingPathComponent("Gestures", isDirectory: true)
            .appendingPathComponent("\(style.rawValue)-\(slot.rawValue).png")
    }
    static func hasCustom(_ slot: HandGestureSlot, style: PointerStyle) -> Bool {
        FileManager.default.fileExists(atPath: url(for: slot, style: style).path)
    }
    static func bundledName(_ slot: HandGestureSlot, style: PointerStyle) -> String? {
        guard PointerStyle.builtInHands.contains(style) else { return nil }
        return "gesture_\(style.rawValue)_\(slot.poseName)"
    }
    static func signature(for style: PointerStyle) -> String {
        guard let name = style.assetName else { return "no-hand" }
        return HandAsset.imageSignature(name) + HandGestureSlot.allCases.map { slot in
            let path = url(for: slot, style: style)
            let bundled = bundledName(slot, style: style).map(HandAsset.bundledImageSignature) ?? "generic"
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path.path) else { return bundled + "|" + HandAsset.imageSignature(slot.assetName) }
            return "\(path.path):\((attrs[.modificationDate] as? Date)?.timeIntervalSince1970.bitPattern ?? 0):\(attrs[.size] ?? 0)"
        }.joined(separator: "|")
    }
    static func image(_ slot: HandGestureSlot, style: PointerStyle) -> CGImage? {
        guard let name = style.assetName else { return nil }
        let key = "\(style.rawValue).\(slot.rawValue)", signature = signature(for: style)
        if let hit = cache[key], hit.signature == signature { return hit.image }
        guard let base = HandAsset.load(name) else { return nil }
        guard let image = resolve(slot, style: style, reference: base) else { return nil }
        if cache.count >= 8 { cache.removeAll() }
        cache[key] = Cached(signature: signature, image: image)
        return image
    }
    /// The injected bundle loader proves fallback order without editing any
    /// shipped resource. Custom files retain their existing validation policy.
    static func resolve(_ slot: HandGestureSlot, style: PointerStyle, reference base: HandAsset,
                        bundledImage: (String) -> CGImage? = HandAsset.loadBundledImage) -> CGImage? {
        guard style.assetName != nil else { return nil }
        if hasCustom(slot, style: style) {
            let url = url(for: slot, style: style)
            return CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
                .flatMap { $0.width == base.image.width && $0.height == base.image.height ? $0 : nil }
        }
        if let name = bundledName(slot, style: style), let image = bundledImage(name),
           image.width == base.image.width, image.height == base.image.height { return image }
        return HandAsset.load(slot.assetName).flatMap { HandMaker.composeGesture($0, reference: base) }
    }
    static func add(from source: URL, slot: HandGestureSlot, style: PointerStyle) throws {
        guard let name = style.assetName, let reference = HandAsset.load(name) else {
            throw HandMaker.Problem(message: "Choose an available hand before adding gesture artwork.")
        }
        let image = try HandMaker.makeGesture(from: source, reference: reference)
        let destination = url(for: slot, style: style)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try HandMaker.write(image, to: destination)
        cache.removeAll()
        NotificationCenter.default.post(name: Preferences.changed, object: nil)
    }
    static func restore(_ slot: HandGestureSlot, style: PointerStyle) throws {
        let path = url(for: slot, style: style)
        if FileManager.default.fileExists(atPath: path.path) { try FileManager.default.removeItem(at: path) }
        cache.removeAll()
        NotificationCenter.default.post(name: Preferences.changed, object: nil)
    }
}

struct HandGestureSession {
    private struct Hold { let owner: String; let slot: HandGestureSlot; let key: UInt32?; let modifiers: UInt32 }
    private var holds: [Hold] = []
    var active: HandGestureSlot? { holds.last?.slot }
    mutating func begin(_ slot: HandGestureSlot, owner: String, shortcut: Shortcut? = nil) {
        guard !holds.contains(where: { $0.owner == owner }) else { return }
        holds.append(Hold(owner: owner, slot: slot, key: shortcut?.keyCode, modifiers: shortcut?.modifiers ?? 0))
    }
    mutating func end(_ owner: String) { holds.removeAll { $0.owner == owner } }
    mutating func releaseKey(_ code: UInt32) { holds.removeAll { $0.key == code } }
    mutating func retainModifiers(_ flags: NSEvent.ModifierFlags) {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        holds.removeAll { $0.key != nil && carbon & $0.modifiers != $0.modifiers }
    }
    mutating func cancel() { holds.removeAll() }
}
