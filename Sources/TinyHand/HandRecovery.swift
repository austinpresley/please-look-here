import Foundation

/// A removal commits only after every owned file has a durable recovery copy.
/// Packages stay inside the Hands folder and survive process exit. No Trash API,
/// user defaults or image decoding is needed by the file transaction itself.
struct HandRecoveryStore {
    struct State: Codable, Equatable {
        var pinnedIDs: [String] = []
        var disabled = false
        var selectedID: String? = nil
        /// Future per-pointer settings can encode their value here before removal
        /// and restore it after the file transaction, without changing its schema.
        var extensions: [String: Data] = [:]
    }

    struct Receipt: Codable, Equatable {
        let version: Int
        let token: UUID
        let removedAt: Date
        let hand: CustomHand
        let index: Int
        let files: [String]
        let state: State
    }

    struct Problem: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    let directory: URL
    var writeManifest: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }
    var removeFile: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
    var writeJournal: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }
    private let fm = FileManager.default
    private var manifest: URL { directory.appendingPathComponent("hands.json") }
    private var recovery: URL { directory.appendingPathComponent(".Removed", isDirectory: true) }

    private func fail(_ message: String) -> Problem { Problem(message: message) }

    private func check(_ url: URL, type: FileAttributeType) throws {
        let attrs = try fm.attributesOfItem(atPath: url.path)
        guard attrs[.type] as? FileAttributeType == type else {
            throw fail("Unable to use \(url.path). Choose a regular Hands folder without symbolic links, then try again.")
        }
    }

    private func exists(_ url: URL) -> Bool {
        // resourceValues also detects dangling symlinks, which must not be followed.
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey])) != nil
    }

    private func validateRoot() throws {
        guard directory.isFileURL, directory.path != "/", !directory.path.isEmpty else {
            throw fail("Unable to locate the Hands folder. Restore its location, then try again.")
        }
        try check(directory, type: .typeDirectory)
        for folder in [directory.appendingPathComponent("Gestures"), recovery] where exists(folder) {
            try check(folder, type: .typeDirectory)
        }
    }

    static func validID(_ id: String) -> Bool {
        id.hasPrefix("custom-") && id.count > 7 && id.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45
        }
    }

    private func ownedFiles(_ id: String) -> [String] {
        ["\(id).png"] + HandGestureSlot.allCases.map { "Gestures/\(id)-\($0.rawValue).png" }
    }

    func readManifest(allowNewLibrary: Bool = false) throws -> [CustomHand] {
        try validateRoot()
        if allowNewLibrary, !exists(manifest), !exists(recovery) { return [] }
        try check(manifest, type: .typeRegular)
        let list: [CustomHand]
        do { list = try JSONDecoder().decode([CustomHand].self, from: Data(contentsOf: manifest)) }
        catch {
            throw fail("Unable to read \(manifest.path). Keep the current file and restore hands.json from a backup, then reopen Settings. \(error.localizedDescription)")
        }
        guard list.allSatisfy({ Self.validID($0.id) }), Set(list.map(\.id)).count == list.count else {
            throw fail("The hand list contains an invalid or repeated ID. Restore hands.json from a backup, then try again.")
        }
        return list
    }

    func package(for receipt: Receipt) -> URL { recovery.appendingPathComponent(receipt.token.uuidString, isDirectory: true) }

    private func receipts() throws -> [Receipt] {
        try validateRoot()
        guard exists(recovery) else { return [] }
        return try fm.contentsOfDirectory(at: recovery, includingPropertiesForKeys: nil).compactMap { folder in
            guard UUID(uuidString: folder.lastPathComponent) != nil else { return nil }
            try check(folder, type: .typeDirectory)
            if try hasMarker("restored", in: folder) { return nil }
            let record = folder.appendingPathComponent("receipt.json")
            guard exists(record) else { return nil } // Incomplete copy, before any removal.
            try check(record, type: .typeRegular)
            let receipt: Receipt
            do { receipt = try JSONDecoder().decode(Receipt.self, from: Data(contentsOf: record)) }
            catch {
                throw fail("Unable to read \(record.path). Keep this recovery package intact. Repair receipt.json from a backup, then reopen Settings. Adding and removing hands is paused. \(error.localizedDescription)")
            }
            guard receipt.version == 1, receipt.token.uuidString == folder.lastPathComponent,
                  Self.validID(receipt.hand.id), receipt.index >= 0,
                  Set(receipt.files).count == receipt.files.count,
                  receipt.files.allSatisfy({ ownedFiles(receipt.hand.id).contains($0) }) else {
                throw fail("Unable to read the removed hand in \(folder.path). Keep this recovery folder and restore it from your backup.")
            }
            return receipt
        }.sorted { $0.removedAt > $1.removedAt }
    }

    private func hasMarker(_ name: String, in folder: URL) throws -> Bool {
        let marker = folder.appendingPathComponent(name)
        guard exists(marker) else { return false }
        try check(marker, type: .typeRegular)
        return true
    }

    func pendingRemovals() throws -> [Receipt] {
        _ = try readManifest()
        // Manifest membership only proves the file phase. Settings may still
        // need replay, including receipts written by the earlier app version.
        return try receipts()
    }

    func restoresAwaitingPreferences() throws -> [Receipt] {
        let list = try readManifest()
        return try receipts().filter { receipt in
            if list.contains(receipt.hand) { return true }
            return try hasMarker("restoring", in: package(for: receipt))
        }
    }

    private func copyBack(_ receipt: Receipt, preserveExisting: Bool = false) throws {
        let folder = package(for: receipt)
        try check(folder, type: .typeDirectory)
        for relative in receipt.files {
            let source = folder.appendingPathComponent(relative)
            try check(source.deletingLastPathComponent(), type: .typeDirectory)
            try check(source, type: .typeRegular)
            let destination = directory.appendingPathComponent(relative)
            if exists(destination) {
                try check(destination, type: .typeRegular)
                if preserveExisting { continue } // Recovery never replaces an existing file.
                guard try Data(contentsOf: destination) == Data(contentsOf: source) else {
                    throw fail("A different file already exists at \(destination.path). Move it aside, then try Undo again.")
                }
            } else {
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: source, to: destination)
            }
        }
    }

    /// A process interrupted before the manifest commit still has its original
    /// membership. Repair missing files from that transaction before loading it.
    func recoverInterruptedRemovals() throws {
        let list = try readManifest()
        for receipt in try receipts() where list.contains(receipt.hand) {
            // A restore intent owns its strict conflict checks and preference
            // replay. An interrupted removal only repairs missing originals.
            if try !hasMarker("restoring", in: package(for: receipt)) {
                try copyBack(receipt, preserveExisting: true)
            }
        }
    }

    func remove(_ id: String, state: State = State()) throws -> Receipt {
        try recoverInterruptedRemovals()
        guard try restoresAwaitingPreferences().isEmpty else {
            throw fail("Finish restoring the recovered hand's settings in Settings before removing another hand.")
        }
        var list = try readManifest()
        guard let index = list.firstIndex(where: { $0.id == id }) else {
            throw fail("This hand is no longer in the library. Refresh Settings and try again.")
        }
        let files = ownedFiles(id).filter { exists(directory.appendingPathComponent($0)) }
        let receipt = Receipt(version: 1, token: UUID(), removedAt: Date(), hand: list[index], index: index, files: files, state: state)
        let folder = package(for: receipt)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for relative in files {
                let source = directory.appendingPathComponent(relative)
                try check(source, type: .typeRegular)
                let destination = folder.appendingPathComponent(relative)
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: source, to: destination)
            }
            try JSONEncoder().encode(receipt).write(to: folder.appendingPathComponent("receipt.json"), options: .atomic)
        } catch {
            throw fail("Unable to prepare recovery for \(receipt.hand.name). Nothing was removed. Check free space and access to \(directory.path), then try again. \(error.localizedDescription)")
        }
        do {
            for relative in files { try removeFile(directory.appendingPathComponent(relative)) }
            list.remove(at: index)
            try writeManifest(JSONEncoder().encode(list), manifest)
        } catch {
            do {
                try copyBack(receipt, preserveExisting: true)
                // The caller has not changed preferences when removal fails.
                try writeJournal(Data(), folder.appendingPathComponent("restored"))
            } catch {
                throw fail("Removal stopped and some files could not be restored. Keep \(folder.path), restore access to the Hands folder, then reopen Settings to retry recovery. \(error.localizedDescription)")
            }
            throw fail("Unable to remove \(receipt.hand.name). The library was restored. Check free space and access to \(directory.path), then try again. \(error.localizedDescription)")
        }
        return receipt
    }

    /// File phase only. The durable intent precedes every file/manifest change.
    /// Completion belongs to the caller after preference persistence succeeds.
    func restoreFiles(_ receipt: Receipt) throws {
        var list = try readManifest()
        guard try receipts().contains(receipt) else {
            throw fail("This recovery folder changed or has already completed. Refresh Settings and try again.")
        }
        if let existing = list.first(where: { $0.id == receipt.hand.id }), existing != receipt.hand {
            throw fail("A different hand already uses this ID. Keep \(package(for: receipt).path) and resolve the conflicting hands.json entry before retrying Undo.")
        }
        do {
            try writeJournal(Data(), package(for: receipt).appendingPathComponent("restoring"))
            try copyBack(receipt)
            if !list.contains(receipt.hand) {
                list.insert(receipt.hand, at: min(receipt.index, list.count))
                try writeManifest(JSONEncoder().encode(list), manifest)
            }
        } catch {
            throw fail("Unable to restore \(receipt.hand.name). Its recovery copy is kept at \(package(for: receipt).path). Check access and free space, then try Undo again. \(error.localizedDescription)")
        }
    }

    func completeRestore(_ receipt: Receipt) throws {
        guard try receipts().contains(receipt), try readManifest().contains(receipt.hand),
              try hasMarker("restoring", in: package(for: receipt)) else {
            throw fail("The hand's file restore is incomplete. Keep \(package(for: receipt).path), then retry Undo in Settings.")
        }
        // Retain the receipt and all backup files even after completion.
        try writeJournal(Data(), package(for: receipt).appendingPathComponent("restored"))
    }
}
