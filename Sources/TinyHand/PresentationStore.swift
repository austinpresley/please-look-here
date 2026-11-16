import Foundation
import Darwin

/// File transactions are independent of the running app, UI and global preferences.
/// Only the injected defaults and canonical owned paths can be changed.
struct PresentationStore {
    let directory: URL
    let storage: UserDefaults
    /// The UI supplies its current catalog availability. Tests may inject it.
    var availableIDs: Set<String>? = nil
    var writeFile: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }
    /// Injectable atomic publication seam for deterministic filesystem failures.
    var moveImportFile: (URL, URL) throws -> Void = { source, destination in
        guard rename(source.path, destination.path) == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: destination.path])
        }
    }
    private let fm = FileManager.default
    private let presetsPath = ".Presentation/presets.json"
    private var recoveryDirectory: URL { directory.appendingPathComponent(".Presentation/Recovery", isDirectory: true) }

    struct PresetDocument: Codable { var version = 1; var presets: [NamedPresentationPreset] }
    struct FileChange: Codable, Equatable {
        let path: String
        let before: Data?
        let after: Data?
    }
    struct Recovery: Codable, Identifiable {
        var version = 1
        let id: UUID
        let created: Date
        let title: String
        /// Binary property lists of allowlisted keys only, preserving absent keys.
        let preferencesBefore: Data
        let preferencesAfter: Data
        let files: [FileChange]
    }
    struct Preview {
        let addedHands: [String]
        let addedArtwork: [String]
        let addedPresets: [String]
        let conflicts: [String]
        let changedSettings: [String]
        let selectedID: String
        let pinnedIDs: [String]
        let disabledIDs: [String]
        let overrideIDs: [String]
        var canApply: Bool { conflicts.isEmpty }
    }
    struct Plan {
        let archive: PortablePresentationArchive
        let preview: Preview
        let files: [FileChange]
        let preferencesAtPreview: Data
        let context: [String: FileStamp]
        let availableIDs: Set<String>?
    }

    /// Metadata, including inode and nanosecond ctime, detects replacement and
    /// in-place edits without decoding or reading artwork on the main queue.
    struct FileStamp: Equatable {
        let device: Int32
        let inode: UInt64
        let mode: UInt16
        let size: Int64
        let modifiedSeconds: Int
        let modifiedNanos: Int
        let changedSeconds: Int
        let changedNanos: Int
    }
    struct PreparedImport {
        fileprivate let plan: Plan
        fileprivate let receipt: Recovery
        fileprivate let staging: URL
        fileprivate let preferences: [String: Any]
        fileprivate let context: [String: FileStamp]
        fileprivate let stagedFiles: [String: FileStamp]
    }

    private func problem(_ message: String) -> PresentationArchiveError { PresentationArchiveError(message: message) }
    private func exists(_ url: URL) -> Bool { (try? fm.attributesOfItem(atPath: url.path)) != nil }

    /// Check every existing component under the explicitly selected root. No
    /// archive field is ever appended until it has passed the canonical allowlist.
    private func safeURL(_ relative: String) throws -> URL {
        guard directory.isFileURL, directory.path != "/", !relative.isEmpty,
              relative.split(separator: "/").allSatisfy({ $0 != "." && $0 != ".." }),
              !relative.hasPrefix("/"), !relative.contains("\\") else { throw problem("Unsafe backup location.") }
        // Reject a symlinked root too. System temporary-directory ancestors may
        // resolve through /var; callers own the explicitly injected root.
        var ancestor = directory
        while ancestor.path != "/" {
            if exists(ancestor) {
                // macOS exposes these standard system directory aliases. All
                // user-controlled ancestors must be actual directories.
                if !["/var", "/tmp"].contains(ancestor.path) { try check(ancestor, directory: true) }
            }
            ancestor.deleteLastPathComponent()
        }
        let parts = relative.split(separator: "/").map(String.init)
        var current = directory
        for (index, part) in parts.enumerated() {
            current.appendPathComponent(part)
            if exists(current) { try check(current, directory: index < parts.count - 1) }
        }
        return current
    }
    private func check(_ url: URL, directory: Bool) throws {
        let type = try fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
        guard type == (directory ? .typeDirectory : .typeRegular) else {
            throw problem("Backup storage contains a symbolic link or unexpected file at \(url.path). Move it aside and try again.")
        }
    }
    private func read(_ path: String, limit: Int = PortablePresentationArchive.maximumBytes) throws -> Data? {
        let url = try safeURL(path)
        guard exists(url) else { return nil }
        let size = try fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber
        guard let size, size.intValue <= limit else { throw problem("Backup file is too large at \(url.path).") }
        let data = try Data(contentsOf: url)
        guard data.count <= limit else { throw problem("Backup file grew beyond its size limit.") }
        return data
    }
    private func put(_ data: Data?, at path: String, injected: Bool = true) throws {
        let url = try safeURL(path)
        if let data {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            _ = try safeURL(path)
            if injected { try writeFile(data, url) } else { try data.write(to: url, options: .atomic) }
        } else if exists(url) { try fm.removeItem(at: url) }
    }

    func presets() throws -> [NamedPresentationPreset] {
        guard let data = try read(presetsPath, limit: 4_000_000) else { return [] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["version", "presets"] else { throw problem("Unknown saved preset fields. Keep the file and update the app.") }
        guard let presets = object["presets"] as? [Any] else { throw problem("Invalid saved preset list.") }
        for preset in presets { try PortablePresentationArchive.checkPreset(preset) }
        let document = try JSONDecoder().decode(PresetDocument.self, from: data)
        guard document.version == 1 else { throw problem("Unsupported saved preset version. Keep the presets file and update the app.") }
        try PortablePresentationArchive.validatePresets(document.presets)
        return document.presets
    }
    private func presetData(_ values: [NamedPresentationPreset]) throws -> Data {
        try PortablePresentationArchive.validatePresets(values)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(PresetDocument(presets: values))
        guard data.count <= 4_000_000 else { throw problem("Saved presets exceed 4 MB.") }
        return data
    }
    private func manifestData(_ values: [CustomHand]) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(values)
    }
    private func hands() throws -> [CustomHand] {
        guard let data = try read("hands.json", limit: 1_000_000) else { return [] }
        guard let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              objects.allSatisfy({ Set($0.keys) == ["id", "name", "ink"] }) else { throw problem("Unknown hand manifest fields. Keep the file and update the app.") }
        let hands = try JSONDecoder().decode([CustomHand].self, from: data)
        guard hands.count <= 256, Set(hands.map { $0.id.lowercased() }).count == hands.count,
              hands.allSatisfy({ HandRecoveryStore.validID($0.id) && $0.id.utf8.count <= 128 }) else { throw problem("Invalid local hand manifest. Restore it before importing.") }
        return hands
    }
    func captureArchive() throws -> PortablePresentationArchive {
        let hands = try hands()
        var artwork: [String: Data] = [:]
        let customIDs = Set(hands.map(\.id))
        var candidates = hands.map { "\($0.id).png" }
        for id in customIDs.union(PortablePresentationArchive.builtInHandIDs) {
            candidates += ["Gestures/\(id)-first.png", "Gestures/\(id)-second.png"]
        }
        for path in candidates { if let data = try read(path, limit: 8_000_000) { artwork[path] = data } }
        let archive = PortablePresentationArchive(setup: try .capture(storage), presets: try presets(), hands: hands, artwork: artwork)
        try archive.validate()
        return archive
    }

    func preview(_ archive: PortablePresentationArchive) throws -> Plan {
        try archive.validate() // No mutation, including no creation of the root.
        let context = try importContext(archive)
        let preferences = currentPreferences()
        let localHands = try hands(), localPresets = try presets()
        var mergedHands = localHands, mergedPresets = localPresets
        var conflicts: [String] = [], files: [FileChange] = []
        var addedHands: [String] = [], addedArtwork: [String] = [], addedPresets: [String] = []
        if exists(try safeURL(".Removed/import-probe").deletingLastPathComponent()) {
            let pending = try HandRecoveryStore(directory: directory).pendingImportHandIDs()
            for hand in archive.hands where pending.contains(hand.id.lowercased()) {
                conflicts.append("Hand \(hand.id) has pending removal recovery. Finish Undo Remove in Settings > Pointers before previewing this backup again.")
            }
        }
        for hand in archive.hands {
            if let existing = localHands.first(where: { $0.id.lowercased() == hand.id.lowercased() }) {
                if existing != hand { conflicts.append("Hand \(hand.id) already has different identity or settings.") }
            } else { mergedHands.append(hand); addedHands.append(hand.name) }
        }
        for (path, data) in archive.artwork.sorted(by: { $0.key < $1.key }) {
            if let existing = try read(path, limit: 8_000_000) {
                if existing != data { conflicts.append("Different artwork already exists at \(path).") }
            } else { files.append(FileChange(path: path, before: nil, after: data)); addedArtwork.append(path) }
        }
        for preset in archive.presets {
            if let existing = localPresets.first(where: { $0.id == preset.id || $0.name.lowercased() == preset.name.lowercased() }) {
                if existing != preset { conflicts.append("Preset \(preset.name) already has different saved settings.") }
            } else { mergedPresets.append(preset); addedPresets.append(preset.name) }
        }
        if mergedHands != localHands {
            guard mergedHands.count <= 256 else { throw problem("The combined library exceeds 256 custom hands.") }
            files.append(FileChange(path: "hands.json", before: try read("hands.json"), after: try manifestData(mergedHands)))
        }
        if mergedPresets != localPresets {
            files.append(FileChange(path: presetsPath, before: try read(presetsPath), after: try presetData(mergedPresets)))
        }
        let current = try PresentationSetup.capture(storage)
        var changed = archive.setup.settings.keys.sorted().compactMap { key -> String? in
            guard let old = current.settings[key], let new = archive.setup.settings[key], old != new else { return nil }
            return "\(PresentationSettingsSchema.titles[key] ?? key): \(PresentationSettingsSchema.display(old)) → \(PresentationSettingsSchema.display(new))"
        }
        if current.selectedID != archive.setup.selectedID { changed.append("Selected pointer: \(current.selectedID) → \(archive.setup.selectedID)") }
        if current.pinnedIDs != archive.setup.pinnedIDs { changed.append("Toolbar pins") }
        if Set(current.disabledIDs) != Set(archive.setup.disabledIDs) { changed.append("Enabled pointers") }
        let oldOverrides = try PointerConfigurationDocument.decode(current.pointerOverrides)
        let newOverrides = try PointerConfigurationDocument.decode(archive.setup.pointerOverrides)
        for id in Set(oldOverrides.pointers.keys).union(newOverrides.pointers.keys).sorted() {
            if oldOverrides.pointers[id] != newOverrides.pointers[id] {
                func description(_ override: PointerOverride?) throws -> String {
                    guard let override, !override.isEmpty else { return "Pointer Defaults" }
                    let fields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(override)) as! [String: Any]
                    return fields.keys.sorted().map { "\($0)=\(fields[$0]!)" }.joined(separator: "; ")
                }
                changed.append("\(id) overrides: \(try description(oldOverrides.pointers[id])) → \(try description(newOverrides.pointers[id]))")
            }
        }
        guard context == (try importContext(archive)), preferencesEqual(preferences, currentPreferences()) else {
            throw staleImport()
        }
        return Plan(archive: archive, preview: Preview(addedHands: addedHands, addedArtwork: addedArtwork,
            addedPresets: addedPresets, conflicts: conflicts, changedSettings: changed,
            selectedID: archive.setup.selectedID, pinnedIDs: archive.setup.pinnedIDs,
            disabledIDs: archive.setup.disabledIDs,
            overrideIDs: try PointerConfigurationDocument.decode(archive.setup.pointerOverrides).pointers.keys.sorted()), files: files,
            preferencesAtPreview: try preferencesData(preferences), context: context, availableIDs: availableIDs)
    }

    /// Background-only convenience for tests and non-UI callers. UI explicitly
    /// prepares off-main and commits on-main to keep validation and staging away
    /// from native preference writers, with no suspension inside final commit.
    @discardableResult func apply(_ plan: Plan) throws -> Recovery {
        guard !Thread.isMainThread else { throw problem("Prepare the backup away from the main queue before committing it.") }
        let prepared = try prepareImport(plan)
        defer { discardImport(prepared) }
        return try DispatchQueue.main.sync { try commitImport(prepared) }
    }

    func prepareImport(_ plan: Plan) throws -> PreparedImport {
        guard !Thread.isMainThread else { throw problem("Backup staging must run away from the main queue.") }
        let refreshed = try preview(plan.archive)
        guard refreshed.preview.canApply else { throw problem(refreshed.preview.conflicts.joined(separator: "\n")) }
        guard refreshed.files == plan.files, refreshed.context == plan.context,
              refreshed.availableIDs == plan.availableIDs,
              preferencesEqual(try decodePreferences(plan.preferencesAtPreview), currentPreferences()) else { throw staleImport() }
        let preferences = try appliedPreferences(plan.archive.setup, importedIDs: Set(plan.archive.hands.map(\.id)))
        let receipt = Recovery(id: UUID(), created: Date(), title: "Import Backup",
            preferencesBefore: plan.preferencesAtPreview, preferencesAfter: try preferencesData(preferences), files: plan.files)
        let staging = try safeURL(".Presentation/Staging/\(receipt.id.uuidString)")
        do {
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            let stagedContext = try importContext(plan.archive)
            // Creating a new Hands root adds ancestor identities. Every identity
            // that existed at preview and every owned-file stamp must still match.
            guard stagedContext.filter({ !$0.key.hasPrefix("ancestor:") || plan.context[$0.key] != nil }) == plan.context else { throw staleImport() }
            for file in plan.files {
                if let data = file.after {
                    let target = staging.appendingPathComponent(file.path)
                    try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try writeFile(data, target)
                }
            }
            // Serialize the large durable journal before entering the main queue.
            let journalData = try JSONEncoder().encode(receipt)
            try writeFile(journalData, staging.appendingPathComponent("journal.json"))
            var stagedFiles: [String: FileStamp] = [:]
            let stagedBytes = plan.files.compactMap { file in file.after.map { (file.path, $0) } } + [("journal.json", journalData)]
            for (path, data) in stagedBytes {
                let url = try safeURL(".Presentation/Staging/\(receipt.id.uuidString)/\(path)")
                let before = try stamp(url)
                guard try Data(contentsOf: url) == data, before == (try stamp(url)), let before else {
                    throw problem("Backup staging changed before it finished. Preview the backup again. Nothing was replaced.")
                }
                stagedFiles[path] = before
            }
            // Prepare canonical parent directories too. No owned file changes.
            for path in plan.files.map(\.path) {
                let url = try safeURL(path)
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            }
            return PreparedImport(plan: plan, receipt: receipt, staging: staging, preferences: preferences, context: stagedContext, stagedFiles: stagedFiles)
        } catch {
            try? fm.removeItem(at: staging)
            throw error
        }
    }

    func discardImport(_ prepared: PreparedImport) {
        try? fm.removeItem(at: prepared.staging)
    }

    /// Native bindings, control commands and hand mutations run on main. Final
    /// validation and publication share that queue, without callbacks or awaits.
    /// Staging contains every byte already; commit does bounded metadata checks,
    /// renames and the allowlisted preference writes. No PNG decode or file copy.
    @discardableResult func commitImport(_ prepared: PreparedImport) throws -> Recovery {
        dispatchPrecondition(condition: .onQueue(.main))
        let plan = prepared.plan
        guard availableIDs == plan.availableIDs, prepared.context == (try importContext(plan.archive)),
              preferencesEqual(try decodePreferences(plan.preferencesAtPreview), currentPreferences()) else { throw staleImport() }
        for (path, expected) in prepared.stagedFiles {
            let url = try safeURL(".Presentation/Staging/\(prepared.receipt.id.uuidString)/\(path)")
            guard try stamp(url) == expected else { throw staleImport() }
        }
        let journal = try safeURL(recoveryPath(prepared.receipt.id))
        // One small directory creation belongs inside the serialization boundary,
        // so another Settings action cannot slip a new Undo journal past preview.
        try fm.createDirectory(at: journal.deletingLastPathComponent(), withIntermediateDirectories: true)
        try moveStaged(prepared.staging.appendingPathComponent("journal.json"), to: journal)
        var published: [FileChange] = []
        do {
            for file in plan.files {
                let target = try safeURL(file.path)
                // Retain the original inode for bounded rollback on a file error.
                if file.before != nil {
                    try fm.moveItem(at: target, to: prepared.staging.appendingPathComponent("before-\(published.count)"))
                }
                published.append(file)
                if file.after != nil { try moveStaged(prepared.staging.appendingPathComponent(file.path), to: target) }
            }
            setPreferences(prepared.preferences)
        } catch {
            // Preferences were never written. Preserve every accepted user edit.
            do {
                for (index, file) in published.enumerated().reversed() {
                    let target = try safeURL(file.path)
                    if exists(target) { try fm.removeItem(at: target) }
                    if file.before != nil { try fm.moveItem(at: prepared.staging.appendingPathComponent("before-\(index)"), to: target) }
                }
                try Data().write(to: try safeURL(".Presentation/Recovery/\(prepared.receipt.id.uuidString).restored"), options: .atomic)
            } catch { throw problem("Import stopped. Recovery is retained at \(recoveryDirectory.path). Restore access, then use Undo Last Change. \(error.localizedDescription)") }
            throw problem("Import could not be saved. The previous files and settings were kept. \(error.localizedDescription)")
        }
        return prepared.receipt
    }

    private func moveStaged(_ source: URL, to destination: URL) throws {
        // POSIX rename is atomic and stays on the same volume as the Hands root.
        try moveImportFile(source, destination)
    }
    private func staleImport() -> PresentationArchiveError {
        problem("The library or settings changed after preview. Preview the backup again before importing. Nothing was replaced.")
    }
    private func preferencesEqual(_ a: [String: Any], _ b: [String: Any]) -> Bool {
        NSDictionary(dictionary: a).isEqual(to: b)
    }
    private func stamp(_ url: URL, directoryOnly: Bool = false) throws -> FileStamp? {
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            if errno == ENOENT { return nil }
            throw problem("Unable to inspect \(url.path). Restore access before importing.")
        }
        return FileStamp(device: info.st_dev, inode: info.st_ino, mode: info.st_mode,
            size: directoryOnly ? 0 : info.st_size,
            modifiedSeconds: directoryOnly ? 0 : info.st_mtimespec.tv_sec,
            modifiedNanos: directoryOnly ? 0 : info.st_mtimespec.tv_nsec,
            changedSeconds: directoryOnly ? 0 : info.st_ctimespec.tv_sec,
            changedNanos: directoryOnly ? 0 : info.st_ctimespec.tv_nsec)
    }
    private func importContext(_ archive: PortablePresentationArchive) throws -> [String: FileStamp] {
        var paths = Set(archive.artwork.keys).union(["hands.json", presetsPath])
        for hand in archive.hands {
            paths.formUnion(["\(hand.id).png", "Gestures/\(hand.id)-first.png", "Gestures/\(hand.id)-second.png"])
        }
        var result: [String: FileStamp] = [:]
        // Missing files are represented by absence; all paths are checked again.
        for path in paths { result[path] = try stamp(safeURL(path)) }
        // Keep root/ancestor identity, allowing our staging directories to appear.
        var ancestor = directory
        while ancestor.path != "/" {
            if let value = try stamp(ancestor, directoryOnly: true) { result["ancestor:" + ancestor.path] = value }
            ancestor.deleteLastPathComponent()
        }
        result[".Presentation/Recovery"] = try stamp(safeURL(".Presentation/Recovery/import-probe").deletingLastPathComponent())
        let removed = try safeURL(".Removed/import-probe").deletingLastPathComponent()
        result[".Removed"] = try stamp(removed)
        if exists(removed) {
            let folders = try fm.contentsOfDirectory(at: removed, includingPropertiesForKeys: nil)
                .filter { UUID(uuidString: $0.lastPathComponent) != nil }
            guard folders.count <= 512 else { throw problem("The hand recovery history is too large for a portable import. Keep .Removed backed up and move completed recovery packages aside before previewing again.") }
            for folder in folders {
                let base = ".Removed/" + folder.lastPathComponent
                result[base] = try stamp(safeURL(base + "/import-probe").deletingLastPathComponent())
                for path in [base + "/receipt.json", base + "/restoring", base + "/restored"] {
                    result[path] = try stamp(safeURL(path))
                }
            }
        }
        return result
    }
    @discardableResult func applyPreset(_ preset: NamedPresentationPreset) throws -> Recovery {
        try preset.validate()
        return try transact(title: "Apply \(preset.name)", preferences: try appliedPreferences(preset.setup), files: [])
    }
    @discardableResult func savePreset(name: String, replacing id: UUID? = nil) throws -> Recovery {
        var values = try presets()
        let value = NamedPresentationPreset(id: id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), setup: try .capture(storage))
        try value.validate()
        if let id {
            guard let index = values.firstIndex(where: { $0.id == id }) else { throw problem("This preset was removed. Refresh the list and try again.") }
            values[index] = value
        } else { values.append(value) }
        return try transact(title: id == nil ? "Save \(value.name)" : "Update \(value.name)", preferences: nil,
            files: [FileChange(path: presetsPath, before: try read(presetsPath), after: try presetData(values))])
    }
    @discardableResult func removePreset(_ id: UUID) throws -> Recovery {
        var values = try presets()
        guard let index = values.firstIndex(where: { $0.id == id }) else { throw problem("This preset was already removed.") }
        let name = values.remove(at: index).name
        return try transact(title: "Remove \(name)", preferences: nil,
            files: [FileChange(path: presetsPath, before: try read(presetsPath), after: try presetData(values))])
    }

    private func appliedPreferences(_ setup: PresentationSetup, importedIDs: Set<String> = []) throws -> [String: Any] {
        var values = setup.preferences
        if let availableIDs {
            let available = availableIDs.union(importedIDs).subtracting(setup.disabledIDs)
            guard !available.isEmpty else {
                throw problem("This setup has no enabled, available pointer. Restore its artwork or update the saved setup before applying it.")
            }
            if !available.contains(setup.selectedID) {
                // Resolve before journaling, so catalog selection repair does not
                // make the application's own Undo look like a later user edit.
                values["pointerStyle"] = ["laser", "spotlight", "presentation"].first(where: available.contains)
                    ?? available.sorted().first ?? setup.selectedID
            }
        }
        return values
    }

    private func currentPreferences() -> [String: Any] {
        Dictionary(uniqueKeysWithValues: PresentationSetup.preferenceKeys.compactMap { key in storage.object(forKey: key).map { (key, $0) } })
    }
    private func preferencesData(_ values: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
    }
    private func decodePreferences(_ data: Data) throws -> [String: Any] {
        guard let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              Set(values.keys).isSubset(of: PresentationSetup.preferenceKeys) else { throw problem("Invalid recovery preferences.") }
        return values
    }
    private func setPreferences(_ values: [String: Any]) {
        for key in PresentationSetup.preferenceKeys {
            if let value = values[key] { storage.set(value, forKey: key) }
            else { storage.removeObject(forKey: key) }
        }
    }
    private func recoveryPath(_ id: UUID) -> String { ".Presentation/Recovery/\(id.uuidString).json" }
    private func transact(title: String, preferences: [String: Any]?, files: [FileChange]) throws -> Recovery {
        let before = currentPreferences()
        let receipt = Recovery(id: UUID(), created: Date(), title: title,
            preferencesBefore: try preferencesData(before), preferencesAfter: try preferencesData(preferences ?? before), files: files)
        for file in files where try read(file.path) != file.before { throw problem("A file changed before saving. Try again.") }
        // Durable journal precedes every user-data write. Keep older journals as
        // local backups, but only the newest can be undone without conflicts.
        try put(JSONEncoder().encode(receipt), at: recoveryPath(receipt.id))
        do {
            for file in files { try put(file.after, at: file.path) }
            if let preferences { setPreferences(preferences) }
        } catch {
            do { try restore(receipt) }
            catch { throw problem("The change stopped. Recovery is retained at \(recoveryDirectory.path). Restore access and use Undo Last Change. \(error.localizedDescription)") }
            throw problem("The change could not be saved. The previous setup was restored. \(error.localizedDescription)")
        }
        return receipt
    }
    func latestRecovery() throws -> Recovery? {
        _ = try safeURL(".Presentation/Recovery/probe.json")
        guard exists(recoveryDirectory) else { return nil }
        let urls = try fm.contentsOfDirectory(at: recoveryDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "json" && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil }
            .sorted {
                ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) >
                ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
            }
        for url in urls {
            let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent)!
            if try read(".Presentation/Recovery/\(id.uuidString).restored", limit: 1) != nil { continue }
            return try readRecovery(id)
        }
        return nil
    }
    private func readRecovery(_ id: UUID) throws -> Recovery? {
        guard let data = try read(recoveryPath(id), limit: 150_000_000) else { return nil }
        let receipt = try JSONDecoder().decode(Recovery.self, from: data)
        guard receipt.version == 1, receipt.id == id, receipt.files.count <= 842,
              receipt.files.allSatisfy({ validRecoveryPath($0.path) }),
              Set(receipt.files.map { $0.path.lowercased() }).count == receipt.files.count else {
            throw problem("Invalid recovery journal. Keep \(recoveryDirectory.path) for recovery.")
        }
        _ = try decodePreferences(receipt.preferencesBefore)
        _ = try decodePreferences(receipt.preferencesAfter)
        return receipt
    }
    private func validRecoveryPath(_ path: String) -> Bool {
        if path == "hands.json" || path == presetsPath { return true }
        let id: String
        if path.hasPrefix("Gestures/") {
            let name = String(path.dropFirst(9))
            if name.hasSuffix("-first.png") { id = String(name.dropLast(10)) }
            else if name.hasSuffix("-second.png") { id = String(name.dropLast(11)) }
            else { return false }
        } else if path.hasSuffix(".png") { id = String(path.dropLast(4)) }
        else { return false }
        return PortablePresentationArchive.validArtworkPath(path, customIDs: HandRecoveryStore.validID(id) ? [id] : [])
    }
    func restore(_ receipt: Recovery) throws {
        guard receipt.version == 1, receipt.files.allSatisfy({ validRecoveryPath($0.path) }) else { throw problem("Invalid recovery record.") }
        let before = try decodePreferences(receipt.preferencesBefore), after = try decodePreferences(receipt.preferencesAfter)
        let current = currentPreferences()
        // Compare per-key, permitting a partially applied transaction or retry.
        func same(_ a: Any?, _ b: Any?) -> Bool {
            if a == nil && b == nil { return true }
            guard let a = a as? NSObject, let b = b as? NSObject else { return false }
            return a.isEqual(b)
        }
        let changedKeys = PresentationSetup.preferenceKeys.filter { !same(before[$0], after[$0]) }
        for key in changedKeys {
            guard same(current[key], before[key]) || same(current[key], after[key]) else {
                throw problem("Settings changed since \(receipt.title). Recovery was kept and nothing was replaced.")
            }
        }
        for file in receipt.files {
            let current = try read(file.path)
            guard current == file.before || current == file.after else { throw problem("\(file.path) changed since \(receipt.title). Recovery was kept and nothing was replaced.") }
        }
        // All conflicts and paths are checked before the first restoration write.
        for file in receipt.files.reversed() { try put(file.before, at: file.path, injected: false) }
        for key in changedKeys {
            if let value = before[key] { storage.set(value, forKey: key) }
            else { storage.removeObject(forKey: key) }
        }
        try put(Data(), at: ".Presentation/Recovery/\(receipt.id.uuidString).restored", injected: false)
    }
}
