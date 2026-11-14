import AppKit
import CoreVideo
import Testing
@testable import TinyHand

private final class DeferredMagnifierDriver: MagnifierCaptureDriver {
    let target: MagnifierTarget
    var frame: ((MagnifierFrame) -> Void)?
    var failure: ((Error) -> Void)?
    var stopCompletion: (() -> Void)?
    var stopImmediately = true
    var stopCount = 0
    init(_ target: MagnifierTarget) { self.target = target }
    func start(frame: @escaping (MagnifierFrame) -> Void, failure: @escaping (Error) -> Void) { self.frame = frame; self.failure = failure }
    func stop(completion: @escaping () -> Void) { stopCount += 1; if stopImmediately { completion() } else { stopCompletion = completion } }
}

@Suite(.serialized) @MainActor struct MagnifierTests {
    private let a = MagnifierTarget(id: 1, frame: CGRect(x: -1920, y: 200, width: 1920, height: 1080), scale: 1)
    private let b = MagnifierTarget(id: 2, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), scale: 2)
    private let c = MagnifierTarget(id: 3, frame: CGRect(x: 1440, y: -600, width: 1280, height: 800), scale: 1)
    private func sample() throws -> MagnifierFrame {
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
        #expect(CVPixelBufferCreate(nil, 32, 32, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer) == kCVReturnSuccess)
        return MagnifierFrame(buffer: try #require(buffer), content: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    @Test func cropUsesDisplayLocalCoordinatesWithoutMixedScaleStretching() throws {
        let layout = try #require(MagnifierLayout(mouse: CGPoint(x: -960, y: 740), display: a.frame, diameter: 240, zoom: 3))
        #expect(layout.lens.midX == 960 && layout.lens.midY == 540)
        #expect(abs(layout.sample.midX - 0.5) < 0.0001 && abs(layout.sample.midY - 0.5) < 0.0001)
        #expect(abs(layout.sample.width * a.frame.width - layout.sample.height * a.frame.height) < 0.0001)
        #expect(abs(layout.cursor.x - 120) < 0.0001 && abs(layout.cursor.y - 120) < 0.0001)
        for point in [a.frame.origin, CGPoint(x: a.frame.maxX, y: a.frame.maxY)] {
            let edge = try #require(MagnifierLayout(mouse: point, display: a.frame, diameter: 480, zoom: 6))
            #expect(CGRect(origin: .zero, size: a.frame.size).contains(edge.lens))
            #expect(edge.sample.minX >= 0 && edge.sample.maxX <= 1 && edge.sample.minY >= 0 && edge.sample.maxY <= 1)
        }
        #expect(MagnifierLayout(mouse: .zero, display: .zero, diameter: 240, zoom: 3) == nil)
    }

    @Test func displayChangesCoalesceWhileTheOldStreamStops() {
        var drivers: [DeferredMagnifierDriver] = []
        let lens = MagnifierController { target in let driver = DeferredMagnifierDriver(target); drivers.append(driver); return driver }
        lens.update(target: a, mouse: a.frame.origin, zoom: 3, diameter: 240)
        drivers[0].stopImmediately = false
        lens.update(target: b, mouse: .zero, zoom: 3, diameter: 240)
        lens.update(target: c, mouse: c.frame.origin, zoom: 3, diameter: 240)
        #expect(drivers.count == 1 && drivers[0].stopCount == 1)
        drivers[0].stopCompletion?()
        #expect(drivers.count == 2 && drivers[1].target.id == 3)
        lens.suspend()
    }

    @Test func lateFramesAndFailuresCannotReviveAStoppedLens() throws {
        var drivers: [DeferredMagnifierDriver] = []
        let lens = MagnifierController { target in let driver = DeferredMagnifierDriver(target); drivers.append(driver); return driver }
        lens.update(target: a, mouse: a.frame.origin, zoom: 3, diameter: 240)
        let frame = try sample()
        drivers[0].frame?(frame)
        #expect(lens.frameCount == 1 && lens.visible)
        lens.suspend()
        drivers[0].frame?(frame); drivers[0].failure?(ScreenshotError.timeout)
        #expect(lens.frameCount == 1 && !lens.visible && lens.lastError == nil)
        lens.update(target: b, mouse: .zero, zoom: 3, diameter: 240)
        drivers[0].failure?(ScreenshotError.display)
        drivers[1].frame?(frame)
        #expect(lens.frameCount == 2 && lens.visible && lens.state == "running")
        lens.suspend()
    }

    @Test func firstFrameDeadlineStopsRatherThanRetryingForever() async throws {
        var driver: DeferredMagnifierDriver?
        let lens = MagnifierController(startupDeadline: 0.02) { target in let next = DeferredMagnifierDriver(target); driver = next; return next }
        var failures = 0; lens.onFailure = { _ in failures += 1 }
        lens.update(target: a, mouse: a.frame.origin, zoom: 3, diameter: 240)
        try await Task.sleep(nanoseconds: 80_000_000)
        #expect(failures == 1 && driver?.stopCount == 1 && !lens.visible && lens.lastError != nil)
    }

    @Test func frameMailboxCoalescesAndInvalidationDropsQueuedFrames() async throws {
        var received = 0
        let mailbox = MagnifierFrameMailbox { _ in received += 1 }
        let frame = try sample()
        for _ in 0..<100 { mailbox.publish(frame) }
        #expect(received == 0)
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(received == 1)
        mailbox.publish(frame); mailbox.invalidate()
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(received == 1)
    }
}
