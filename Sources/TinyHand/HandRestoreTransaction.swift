import Foundation

/// Coordinates two persistence owners without pretending they share a commit.
/// Unfinished receipts remain actionable and replay against current preferences.
struct HandRestoreTransaction {
    let store: HandRecoveryStore
    let preferences: UserDefaults
    var afterFiles: () throws -> Void = {}
    var persistPreferences: (UserDefaults) -> Bool = { $0.synchronize() }
    var afterPreferences: () throws -> Void = {}

    func restore(_ receipt: HandRecoveryStore.Receipt) throws {
        do {
            // Validate the one-ID payload against the current archive before
            // touching files. Legacy receipts leave the override archive alone.
            let payload = receipt.state.extensions[PointerRemovalConfiguration.receiptKey]
            _ = try payload.map {
                try PointerRemovalConfiguration.restoredArchive($0, for: receipt.hand.id,
                    in: PointerConfigurationDocument.load(from: preferences))
            }
            let knownIDs = Set(try store.readManifest().map(\.id) + [receipt.hand.id]
                + PointerStyle.builtInHands.map(\.rawValue) + PointerStyle.presentationStyles.map(\.rawValue))
            var seen = Set<String>()
            let pins = receipt.state.pinnedIDs.filter { knownIDs.contains($0) && seen.insert($0).inserted }
            guard pins.count <= Preferences.maxPinned else {
                throw HandRecoveryStore.Problem(message: "The recovery toolbar has too many pins. Repair the receipt from a backup, then retry Undo.")
            }
            try store.restoreFiles(receipt)
            try afterFiles()

            // Re-read enabled IDs at the preference boundary. Unrelated pointers
            // keep their current values. Only this hand's override is replaced.
            if let payload {
                let configuration = try PointerRemovalConfiguration.restoredArchive(payload, for: receipt.hand.id,
                    in: PointerConfigurationDocument.load(from: preferences))
                preferences.set(configuration, forKey: PointerConfigurationDocument.storageKey)
            }
            var disabled = Set(preferences.stringArray(forKey: "disabledPointerIDs") ?? [])
            if receipt.state.disabled { disabled.insert(receipt.hand.id) }
            else { disabled.remove(receipt.hand.id) }
            preferences.set(disabled.sorted(), forKey: "disabledPointerIDs")
            if pins.contains(receipt.hand.id) { preferences.set(pins, forKey: "pinnedStyles") }
            // Keep the existing selection. Restoring an absent/disabled hand must
            // not steal the current pointer or alter activation/shortcuts.
            guard persistPreferences(preferences) else {
                throw HandRecoveryStore.Problem(message: "The recovered settings could not be saved. Check disk space and preference access, then retry Undo.")
            }
            try afterPreferences()
            try store.completeRestore(receipt)
        } catch {
            throw HandRecoveryStore.Problem(message: "Unable to finish restoring \(receipt.hand.name). Keep \(store.package(for: receipt).path) intact. Reopen Settings or retry Undo after fixing the reported problem. \(error.localizedDescription)")
        }
    }
}
