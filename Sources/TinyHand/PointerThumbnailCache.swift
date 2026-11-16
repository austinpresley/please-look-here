import AppKit
import Darwin
import ImageIO
import UniformTypeIdentifiers

/// Main-queue catalog ownership, with PNG encoding on a dedicated utility queue.
/// Keep the encoded bytes too, so a removed export needs a rewrite, not a render.
final class PointerThumbnailCache {
    private struct Cached {
        let assetSignature: String
        let png: Data
        var outputSignature: String?
    }
    private var cache: [String: Cached] = [:]
    private let outputDirectory: () -> String
    private let encode: (CGImage) throws -> Data
    private let queue = DispatchQueue(label: "app.tinyhand.thumbnail-export", qos: .utility)
    private(set) var lastError: String?

    private final class EncodingWork {
        let image: CGImage
        let encoder: (CGImage) throws -> Data
        let done = DispatchSemaphore(value: 0)
        var result: Result<Data, Error>?
        init(image: CGImage, encoder: @escaping (CGImage) throws -> Data) {
            self.image = image
            self.encoder = encoder
        }
        func run() {
            result = Result { try encoder(image) }
            done.signal()
        }
    }

    init(outputDirectory: @escaping () -> String = { ControlTransport.thumbnailDirectory },
         encode: @escaping (CGImage) throws -> Data = PointerThumbnailCache.encodePNG) {
        self.outputDirectory = outputDirectory
        self.encode = encode
    }

    static func signature(for style: PointerStyle) -> String {
        // Bump the renderer version if a generated/cropped native icon changes.
        "native-thumbnail-v1:" + (style.assetName.map(HandAsset.imageSignature) ?? style.rawValue)
    }

    static func encodePNG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw ControlTransport.Failure(message: "Cannot prepare the pointer thumbnail")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ControlTransport.Failure(message: "Cannot encode the pointer thumbnail")
        }
        return data as Data
    }

    private func fileSignature(_ url: URL) throws -> String? {
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            if errno == ENOENT { return nil }
            throw ControlTransport.Failure(message: "Cannot read the pointer thumbnail")
        }
        guard info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid() else {
            throw ControlTransport.Failure(message: "Unsafe pointer thumbnail file")
        }
        return "\(info.st_ino):\(info.st_size):\(info.st_mtimespec.tv_sec):\(info.st_mtimespec.tv_nsec):\(info.st_ctimespec.tv_sec):\(info.st_ctimespec.tv_nsec)"
    }

    func path(for id: String, signature: String, image: () -> NSImage?) -> String? {
        do {
            let directory = try ControlTransport.secureOutputDirectory(outputDirectory())
            // Preserve the established filenames, encoding IDs rather than using
            // custom identifiers as unchecked path components.
            let filename = Data(id.utf8).map { String(format: "%02x", $0) }.joined() + ".png"
            let url = directory.appendingPathComponent(filename)
            let key = url.path
            let outputSignature = try fileSignature(url)
            if let hit = cache[key], hit.assetSignature == signature,
               let outputSignature, hit.outputSignature == outputSignature {
                lastError = nil
                return url.path
            }
            var record: Cached
            if let hit = cache[key], hit.assetSignature == signature {
                record = hit
            } else {
                // Resolve lazy AppKit artwork on the catalog's main queue; only
                // the immutable CGImage crosses to the encoder's utility queue.
                guard let cg = image()?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
                // dispatch_sync may execute on the caller's thread. Explicitly
                // enqueue the encoder so even the first PNG is encoded off-main.
                let work = EncodingWork(image: cg, encoder: encode)
                queue.async { work.run() }
                work.done.wait()
                let png = try work.result!.get()
                record = Cached(assetSignature: signature, png: png, outputSignature: nil)
            }
            cache[key] = record // A failed write can retry without re-encoding.
            try record.png.write(to: url, options: .atomic)
            record.outputSignature = try fileSignature(url)
            cache[key] = record
            lastError = nil
            return url.path
        } catch {
            lastError = (error as? ControlTransport.Failure)?.message ?? error.localizedDescription
            return nil
        }
    }

    func retain(ids: Set<String>) {
        let filenames = Set(ids.map { Data($0.utf8).map { String(format: "%02x", $0) }.joined() + ".png" })
        cache = cache.filter { filenames.contains(URL(fileURLWithPath: $0.key).lastPathComponent) }
    }
}
