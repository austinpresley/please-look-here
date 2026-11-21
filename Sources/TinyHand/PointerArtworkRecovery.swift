import AppKit

/// Artwork replacement never overwrites the previous bytes without a durable copy.
/// Undo refuses to replace a later edit. Recovery files remain in the Hands folder.
struct PointerArtworkRecovery {
    let target: URL
    let folder: URL
    let replacement: Data
    let previous: Data?
    static func replace(style: PointerStyle, image: CGImage, directory: URL) throws -> Self {
        guard let name = style.assetName else { throw HandRecoveryStore.Problem(message: "Choose a hand to restore artwork.") }
        return try replace(id: name, image: image, directory: directory)
    }
    static func replace(id: String, image: CGImage, directory: URL) throws -> Self {
        guard PointerConfigurationDocument.validID(id) else { throw HandRecoveryStore.Problem(message: "Invalid pointer ID.") }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent("\(id).png")
        if let values = try? target.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
            throw HandRecoveryStore.Problem(message: "Restore a regular artwork file, without a symbolic link.")
        }
        let previous = fm.fileExists(atPath: target.path) ? try Data(contentsOf: target) : nil
        let folder = directory.appendingPathComponent(".ArtworkRecovery/\(id)-\(UUID().uuidString)")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        if let previous { try previous.write(to: folder.appendingPathComponent("previous.png"), options: .atomic) }
        try HandMaker.write(image, to: folder.appendingPathComponent("replacement.png"))
        let replacement = try Data(contentsOf: folder.appendingPathComponent("replacement.png"))
        try replacement.write(to: target, options: .atomic)
        return Self(target: target, folder: folder, replacement: replacement, previous: previous)
    }
    func undo() throws {
        guard try Data(contentsOf: target) == replacement else {
            throw HandRecoveryStore.Problem(message: "Artwork changed after restoration. The recovery copy is kept at \(folder.path).")
        }
        if let previous { try previous.write(to: target, options: .atomic) }
        else { try FileManager.default.removeItem(at: target) }
    }
}

extension SettingsModel {
    func renameHand(_ style: PointerStyle, name: String) {
        do { try CustomHands.rename(style, name: name); handMessage = "Hand renamed." }
        catch { handMessage = error.localizedDescription }
        refresh()
    }
    func choosePointerArtwork(_ style: PointerStyle) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .webP, .image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose transparent artwork to restore \(style.title). The current local artwork is kept in a recovery copy."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard let assetName = style.assetName else { return }
            let draft = try HandMaker.make(from: url)
            artworkRecovery = try PointerArtworkRecovery.replace(style: style, image: draft.image, directory: CustomHands.directory)
            HandAsset.forget(assetName); Preferences.notifyPointerConfigurationChanged(); handMessage = "Artwork restored. Undo is available in the inspector."; refresh()
        } catch { handMessage = error.localizedDescription }
    }
    func undoArtwork(_ receipt: PointerArtworkRecovery) {
        do { try receipt.undo(); HandAsset.forget(receipt.target.deletingPathExtension().lastPathComponent); artworkRecovery = nil; Preferences.notifyPointerConfigurationChanged(); handMessage = "Previous artwork restored." }
        catch { handMessage = error.localizedDescription }
        refresh()
    }
}
