import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct PointerThumbnailTests {
    private struct Fixture {
        let root: URL
        var output: URL { root.appendingPathComponent("Thumbnails") }
        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("thumbnail-cache-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        func finish() { try? FileManager.default.removeItem(at: root) }
    }
    private final class Encodings {
        private let lock = NSLock()
        private var count = 0
        private var usedMain = false
        func encode(_ image: CGImage) throws -> Data {
            lock.lock()
            count += 1; usedMain = usedMain || Thread.isMainThread
            lock.unlock()
            return try PointerThumbnailCache.encodePNG(image)
        }
        var values: (Int, Bool) {
            lock.lock(); defer { lock.unlock() }
            return (count, usedMain)
        }
    }
    private func image(_ red: CGFloat = 0.5) throws -> NSImage {
        let context = try #require(CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: red, green: 0.2, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
        return NSImage(cgImage: try #require(context.makeImage()), size: NSSize(width: 64, height: 64))
    }

    @Test func unchangedCatalogReusesFilesWithoutRenderingOrEncodingAgain() throws {
        let f = try Fixture(); defer { f.finish() }
        let encodings = Encodings()
        let cache = PointerThumbnailCache(outputDirectory: { f.output.path }, encode: encodings.encode)
        let icon = try image()
        var renders = 0
        func export(_ signature: String) -> String? {
            cache.path(for: "custom-fixture", signature: signature) { renders += 1; return icon }
        }
        let path = try #require(export("asset-1"))
        let before = try FileManager.default.attributesOfItem(atPath: path)
        let bytes = try Data(contentsOf: URL(fileURLWithPath: path))
        for _ in 0..<20 { #expect(export("asset-1") == path) }
        let after = try FileManager.default.attributesOfItem(atPath: path)
        #expect(renders == 1 && encodings.values.0 == 1)
        #expect(!encodings.values.1)
        #expect(before[.modificationDate] as? Date == after[.modificationDate] as? Date)
        #expect(before[.systemFileNumber] as? NSNumber == after[.systemFileNumber] as? NSNumber)
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == bytes)
        #expect(export("asset-2") == path)
        #expect(renders == 2 && encodings.values.0 == 2)
        #expect(!encodings.values.1)
    }

    @Test func deletedOrAlteredExportReusesEncodedBytesAndNeverFollowsSymlinks() throws {
        let f = try Fixture(); defer { f.finish() }
        let encodings = Encodings()
        let cache = PointerThumbnailCache(outputDirectory: { f.output.path }, encode: encodings.encode)
        let icon = try image()
        let path = try #require(cache.path(for: "laser", signature: "one", image: { icon }))
        let url = URL(fileURLWithPath: path)
        let bytes = try Data(contentsOf: url)
        try FileManager.default.removeItem(at: url)
        #expect(cache.path(for: "laser", signature: "one", image: { Issue.record("Unexpected render"); return nil }) == path)
        #expect(try Data(contentsOf: url) == bytes)
        try Data("changed export".utf8).write(to: url, options: .atomic)
        #expect(cache.path(for: "laser", signature: "one", image: { nil }) == path)
        #expect(try Data(contentsOf: url) == bytes)
        #expect(encodings.values.0 == 1)
        let outside = f.root.appendingPathComponent("keep.png")
        try Data("keep me".utf8).write(to: outside)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: outside)
        #expect(cache.path(for: "laser", signature: "two", image: { icon }) == nil)
        #expect(try Data(contentsOf: outside) == Data("keep me".utf8))
        #expect(encodings.values.0 == 1)
    }

    @Test func emptyRelativeCheckoutAndUnsafeDirectoriesCannotRenderOrWrite() throws {
        let f = try Fixture(); defer { f.finish() }
        let cwd = FileManager.default.currentDirectoryPath
        let before = Set(try FileManager.default.contentsOfDirectory(atPath: cwd))
        let publicDir = f.root.appendingPathComponent("public")
        try FileManager.default.createDirectory(at: publicDir, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o755])
        let target = f.root.appendingPathComponent("private")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        let link = f.root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let notDirectory = f.root.appendingPathComponent("file")
        try Data().write(to: notDirectory)
        for path in ["", ".", "relative-dir", "/", cwd, cwd + "/thumbnail-test-must-not-be-created", publicDir.path, link.path,
                     notDirectory.path, f.root.appendingPathComponent("absent/child").path] {
            let cache = PointerThumbnailCache(outputDirectory: { path })
            #expect(cache.path(for: "../../unsafe", signature: "one", image: {
                Issue.record("Unsafe directory must fail before rendering"); return nil
            }) == nil)
            #expect(cache.lastError != nil)
        }
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: cwd)) == before)
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty)
    }

    @Test func changedCustomAssetSignatureInvalidatesOnlyItsThumbnail() throws {
        try #require(ProcessInfo.processInfo.environment["TH_HANDS_DIR"] != nil)
        try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        let custom = try CustomHands.add(try #require(HandAsset.load("hand_lavender")?.image), ink: 0, name: "Thumbnail fixture")
        defer { _ = try? CustomHands.remove(custom) }
        let f = try Fixture(); defer { f.finish() }
        let encodings = Encodings()
        let cache = PointerThumbnailCache(outputDirectory: { f.output.path }, encode: encodings.encode)
        let icon = try image()
        let first = PointerThumbnailCache.signature(for: custom)
        let stock = PointerThumbnailCache.signature(for: .laser)
        #expect(cache.path(for: custom.rawValue, signature: first, image: { icon }) != nil)
        #expect(cache.path(for: "laser", signature: stock, image: { icon }) != nil)
        let asset = CustomHands.directory.appendingPathComponent(custom.rawValue + ".png")
        let date = Date(timeIntervalSince1970: 1_600_000_000)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: asset.path)
        let changed = PointerThumbnailCache.signature(for: custom)
        #expect(changed != first)
        #expect(cache.path(for: custom.rawValue, signature: changed, image: { icon }) != nil)
        #expect(cache.path(for: "laser", signature: stock, image: { Issue.record("Stock icon changed"); return nil }) != nil)
        #expect(encodings.values.0 == 3)
        let files = try FileManager.default.contentsOfDirectory(atPath: f.output.path)
        #expect(files.count == 2 && files.allSatisfy { $0.hasSuffix(".png") && !$0.contains("..") })
    }

    @Test func actualStylesPollingKeepsEveryExportStable() throws {
        let output = ControlTransport.thumbnailDirectory
        try #require(!output.isEmpty, "Run with an isolated TH_THUMBNAILS_DIR")
        _ = NSApplication.shared
        let api = ControlBridge(overlay: OverlayController(), openSettings: { _ in }, openHandCreator: {})
        let request = try JSONSerialization.data(withJSONObject: ["version": 1, "operation": "styles"])
        func paths() throws -> [String] {
            let response = try #require(JSONSerialization.jsonObject(with: api.handle(request)) as? [String: Any])
            #expect(response["ok"] as? Bool == true)
            let styles = try #require(response["styles"] as? [[String: Any]])
            let paths = styles.compactMap { $0["thumbnail"] as? String }
            #expect(paths.count == styles.filter { $0["available"] as? Bool == true }.count)
            return paths
        }
        let first = try paths()
        #expect(!first.isEmpty)
        let stamps = try first.map { try FileManager.default.attributesOfItem(atPath: $0)[.modificationDate] as? Date }
        #expect(try paths() == first)
        #expect(try paths() == first)
        #expect(try first.map { try FileManager.default.attributesOfItem(atPath: $0)[.modificationDate] as? Date } == stamps)
        #expect(first.allSatisfy { $0.hasPrefix(output + "/") })
    }
}
