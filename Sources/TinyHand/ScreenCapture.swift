import AppKit
import CoreImage
import ScreenCaptureKit

enum ScreenshotError: LocalizedError {
    case permission, display, timeout, encoding
    var errorDescription: String? {
        switch self {
        case .permission: return "Allow TinyHand in System Settings → Privacy & Security → Screen & System Audio Recording, then try the screenshot again. You may need to reopen the app."
        case .display: return "The display is no longer available. Move the pointer to a connected display and try again."
        case .timeout: return "The screen did not produce a frame. Try the screenshot again."
        case .encoding: return "The screenshot could not be encoded as a PNG. Try again."
        }
    }
}

/// Includes the overlay, excludes every other window belonging to this app.
final class ScreenCapture {
    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }
    static func requestPermission() { _ = CGRequestScreenCaptureAccess() }
    static func openPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") { NSWorkspace.shared.open(url) }
    }

    @MainActor func screenshot(screen: NSScreen, overlayID: CGWindowID) async throws -> CGImage {
        guard Self.hasPermission else { Self.requestPermission(); throw ScreenshotError.permission }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        guard let display = content.displays.first(where: { $0.displayID == id }) else { throw ScreenshotError.display }
        let excluded = content.windows.filter { $0.owningApplication?.processID == getpid() && $0.windowID != overlayID }
        let filter = SCContentFilter(display: display, excludingWindows: excluded)
        let config = SCStreamConfiguration()
        if #available(macOS 14, *) {
            config.width = max(1, Int(filter.contentRect.width * CGFloat(filter.pointPixelScale)))
            config.height = max(1, Int(filter.contentRect.height * CGFloat(filter.pointPixelScale)))
        } else {
            config.width = max(1, Int(screen.frame.width * screen.backingScaleFactor))
            config.height = max(1, Int(screen.frame.height * screen.backingScaleFactor))
        }
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        if #available(macOS 14, *) { return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) }
        return try await SingleScreenshotFrame().grab(filter: filter, configuration: config)
    }

    static func png(_ image: CGImage) throws -> Data {
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw ScreenshotError.encoding }
        return data
    }

    static func save(_ data: Data, in folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let filename = "TinyHand \(formatter.string(from: Date())) \(UUID().uuidString.prefix(6)).png"
        let url = folder.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    @discardableResult
    static func copy(_ data: Data, to pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setData(data, forType: .png)
    }
}

/// macOS 13 fallback with a bounded wait and exactly-once continuation completion.
@MainActor private final class SingleScreenshotFrame: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "tinyhand.screenshot.frame")
    private var continuation: CheckedContinuation<CGImage, Error>?
    private var stream: SCStream?
    private var timeout: Task<Void, Never>?

    func grab(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        try await withCheckedThrowingContinuation { completion in
            continuation = completion
            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            self.stream = stream
            do { try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue) }
            catch { finish(.failure(error)); return }
            timeout = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 4_000_000_000) } catch { return }
                self?.finish(.failure(ScreenshotError.timeout))
            }
            stream.startCapture { @Sendable [weak self] error in
                if let error = error { Task { @MainActor in self?.finish(.failure(error)) } }
            }
        }
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let image = CIContext().createCGImage(ci, from: ci.extent) else { return }
        Task { @MainActor in self.finish(.success(image)) }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) { Task { @MainActor in self.finish(.failure(error)) } }

    private func finish(_ result: Result<CGImage, Error>) {
        guard let completion = continuation else { return }
        continuation = nil
        timeout?.cancel(); timeout = nil
        stream?.stopCapture { _ in }
        stream = nil
        completion.resume(with: result)
    }
}
