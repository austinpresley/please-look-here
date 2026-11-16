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

    func readManifest() throws -> [CustomHand] {
        try validateRoot()
        try check(manifest, type: .typeRegular)
        let list = try JSONDecoder().decode([CustomHand].self, from: Data(contentsOf: manifest))
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
            if exists(folder.appendingPathComponent("restored")) { return nil }
            let record = folder.appendingPathComponent("receipt.json")
            guard exists(record) else { return nil } // Incomplete copy, before any removal.
            try check(record, type: .typeRegular)
            let receipt = try JSONDecoder().decode(Receipt.self, from: Data(contentsOf: record))
            guard receipt.version == 1, receipt.token.uuidString == folder.lastPathComponent,
                  Self.validID(receipt.hand.id), receipt.index >= 0,
                  Set(receipt.files).count == receipt.files.count,
                  receipt.files.allSatisfy({ ownedFiles(receipt.hand.id).contains($0) }) else {
                throw fail("Unable to read the removed hand in \(folder.path). Keep this recovery folder and restore it from your backup.")
            }
            return receipt
        }.sorted { $0.removedAt > $1.removedAt }
    }

    func pendingRemovals() throws -> [Receipt] {
        let ids = Set(try readManifest().map(\.id))
        return try receipts().filter { !ids.contains($0.hand.id) }
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
            try copyBack(receipt, preserveExisting: true)
            try Data().write(to: package(for: receipt).appendingPathComponent("restored"), options: .atomic)
        }
    }

    func remove(_ id: String, state: State = State()) throws -> Receipt {
        try recoverInterruptedRemovals()
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
            do { try copyBack(receipt, preserveExisting: true) }
            catch {
                throw fail("Removal stopped and some files could not be restored. Keep \(folder.path), restore access to the Hands folder, then reopen Settings to retry recovery. \(error.localizedDescription)")
            }
            throw fail("Unable to remove \(receipt.hand.name). The library was restored. Check free space and access to \(directory.path), then try again. \(error.localizedDescription)")
        }
        return receipt
    }

    @discardableResult
    func restore(_ receipt: Receipt) throws -> String? {
        var list = try readManifest()
        guard !list.contains(where: { $0.id == receipt.hand.id }), try receipts().contains(receipt) else {
            throw fail("This hand has already been restored or its recovery folder changed. Refresh Settings and try again.")
        }
        // Keep the package intact until both artwork and manifest are restored.
        // A failed/restarted Undo can safely reuse identical copied files.
        do {
            try copyBack(receipt)
            list.insert(receipt.hand, at: min(receipt.index, list.count))
            try writeManifest(JSONEncoder().encode(list), manifest)
        } catch {
            throw fail("Unable to restore \(receipt.hand.name). Its recovery copy is kept at \(package(for: receipt).path). Check access and free space, then try Undo again. \(error.localizedDescription)")
        }
        // Files remain as a backup; marking avoids reapplying old recovery later.
        do {
            try Data().write(to: package(for: receipt).appendingPathComponent("restored"), options: .atomic)
            return nil
        } catch {
            return "The hand was restored. Keep its backup at \(package(for: receipt).path); recovery bookkeeping could not be updated. \(error.localizedDescription)"
        }
    }
}
