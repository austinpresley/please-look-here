import AppKit
import CoreMedia
import CoreVideo
import ScreenCaptureKit

/// At most one displayed frame and one pending replacement retain capture buffers.
final class MagnifierFrameMailbox {
    private let lock = NSLock()
    private var pending: MagnifierFrame?
    private var scheduled = false
    private var valid = true
    let deliver: (MagnifierFrame) -> Void
    init(deliver: @escaping (MagnifierFrame) -> Void) { self.deliver = deliver }
    func publish(_ frame: MagnifierFrame) {
        let schedule = lock.withLock { () -> Bool in
            guard valid else { return false }
            pending = frame
            guard !scheduled else { return false }
            scheduled = true; return true
        }
        if schedule { DispatchQueue.main.async { [weak self] in self?.flush() } }
    }
    func invalidate() { lock.withLock { valid = false; pending = nil } }
    private func flush() {
        let frame = lock.withLock { () -> MagnifierFrame? in
            scheduled = false
            defer { pending = nil }
            return valid ? pending : nil
        }
        if let frame { deliver(frame) }
    }
}

/// ScreenCaptureKit details stay behind the same interface as the delayed test driver.
final class ScreenMagnifierCapture: NSObject, MagnifierCaptureDriver, SCStreamOutput, SCStreamDelegate {
    private let target: MagnifierTarget
    private let queue = DispatchQueue(label: "Look Here Please magnifier frames", qos: .userInitiated)
    private var stream: SCStream?
    private var startup: Task<Void, Never>?
    private var mailbox: MagnifierFrameMailbox?
    private var failure: ((Error) -> Void)?
    private var stopped = false
    private var stopCompletions: [() -> Void] = []
    private var stopTimeout: DispatchWorkItem?
    private let mailboxLock = NSLock()

    init(target: MagnifierTarget) { self.target = target }
    func start(frame: @escaping (MagnifierFrame) -> Void, failure: @escaping (Error) -> Void) {
        self.failure = failure
        mailboxLock.withLock { mailbox = MagnifierFrameMailbox(deliver: frame) }
        startup = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                guard !self.stopped, !Task.isCancelled else { return }
                guard let display = content.displays.first(where: { $0.displayID == self.target.id }),
                      let ownApp = content.applications.first(where: { $0.processID == getpid() }) else { throw ScreenshotError.display }
                // Exclude the whole app, including windows created after startup.
                // A screenshot's overlay-inclusive filter would feed the lens into itself.
                let filter = SCContentFilter(display: display, excludingApplications: [ownApp], exceptingWindows: [])
                let config = SCStreamConfiguration()
                if #available(macOS 14, *) {
                    config.width = max(1, Int(ceil(filter.contentRect.width * CGFloat(filter.pointPixelScale))))
                    config.height = max(1, Int(ceil(filter.contentRect.height * CGFloat(filter.pointPixelScale))))
                } else {
                    config.width = max(1, Int(ceil(self.target.frame.width * self.target.scale)))
                    config.height = max(1, Int(ceil(self.target.frame.height * self.target.scale)))
                }
                config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                config.queueDepth = 3; config.showsCursor = false; config.capturesAudio = false
                config.pixelFormat = kCVPixelFormatType_32BGRA
                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.queue)
                self.stream = stream
                try await stream.startCapture()
                if self.stopped || Task.isCancelled { try? await stream.stopCapture() }
            } catch {
                if !self.stopped && !Task.isCancelled { failure(error) }
            }
        }
    }
    func stop(completion: @escaping () -> Void) {
        stopped = true
        startup?.cancel(); startup = nil
        mailboxLock.withLock { mailbox?.invalidate(); mailbox = nil }
        failure = nil
        guard let stream else { completion(); return }
        stopCompletions.append(completion)
        self.stream = nil
        let timeout = DispatchWorkItem { [weak self] in self?.finishStop() }
        stopTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: timeout)
        stream.stopCapture { @Sendable [weak self] _ in DispatchQueue.main.async { self?.finishStop() } }
    }
    private func finishStop() {
        stopTimeout?.cancel(); stopTimeout = nil
        let completions = stopCompletions; stopCompletions = []
        completions.forEach { $0() }
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer), CVPixelBufferGetIOSurface(buffer) != nil else { return }
        let width = CGFloat(CVPixelBufferGetWidth(buffer)), height = CGFloat(CVPixelBufferGetHeight(buffer))
        let rect = (attachments.first?[.contentRect] as? CGRect) ?? CGRect(x: 0, y: 0, width: width, height: height)
        let valid = CGRect(x: rect.minX / width, y: (height - rect.maxY) / height,
                           width: rect.width / width, height: rect.height / height).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !valid.isEmpty else { return }
        let target = mailboxLock.withLock { mailbox }
        target?.publish(MagnifierFrame(buffer: buffer, content: valid))
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.stopped, self.stream === stream else { return }
            self.failure?(error)
        }
    }
}
