import Foundation

/// Recovery receipts contain only the removed pointer's override, including
/// an empty snapshot that explicitly restores inheritance for that pointer.
enum PointerRemovalConfiguration {
    static let receiptKey = "pointer-overrides.v1"

    static func snapshot(for id: String, in document: PointerConfigurationDocument) throws -> Data {
        var snapshot = PointerConfigurationDocument()
        try snapshot.replace(document.pointers[id], for: id)
        return try snapshot.encoded()
    }

    static func restoredArchive(_ payload: Data, for id: String,
                                in document: PointerConfigurationDocument) throws -> Data {
        let snapshot = try PointerConfigurationDocument.decode(payload)
        guard Set(snapshot.pointers.keys).isSubset(of: [id]) else {
            throw PointerConfigurationError.invalid("The recovery settings do not match this hand. Restore its settings from a backup.")
        }
        var restored = document
        try restored.replace(snapshot.pointers[id], for: id)
        return try restored.encoded()
    }
}
