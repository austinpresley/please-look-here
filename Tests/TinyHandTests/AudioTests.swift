import AppKit
import AVFoundation
import Testing
@testable import TinyHand

private final class AudioProbe {
    private let lock = NSLock()
    private var events: [String] = []
    private var callbacks: [() -> Void] = []
    var delay: useconds_t = 0
    var render = true
    var blockStart: (() -> Void)?
    func note(_ value: String) { lock.withLock { events.append("\(Thread.isMainThread ? "main" : "background"):\(value)") } }
    func remember(_ callback: @escaping () -> Void) { lock.withLock { callbacks.append(callback) } }
    func changed() { let callback = lock.withLock { callbacks.last }; callback?() }
    var recorded: [String] { lock.withLock { events } }
}
private final class ProbeAudioDriver: TapAudioDriver {
    let probe: AudioProbe
    var isRunning = false
    init(_ probe: AudioProbe, changed: @escaping () -> Void) { self.probe = probe; probe.remember(changed) }
    func start() throws { probe.note("start"); probe.blockStart?(); if probe.delay > 0 { usleep(probe.delay) }; isRunning = true }
    func play(_ buffer: AVAudioPCMBuffer, rendered: @escaping () -> Void) { probe.note("play"); if probe.render { rendered() } }
    func stop() { probe.note("stop"); isRunning = false }
}

@Suite(.serialized) @MainActor struct AudioTests {
    @Test func everySoundHasADecodablePackagedSourceFile() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        #expect(TapSoundChoice.allCases.count == 15)
        for sound in TapSoundChoice.allCases {
            let audio = try AVAudioFile(forReading: root.appendingPathComponent("assets/sounds/tap_\(sound.rawValue).wav"))
            #expect(audio.length > 0 && audio.processingFormat.sampleRate > 0)
        }
    }
    @Test func blockedAudioDeviceNeverBlocksTheCaller() async {
        let probe = AudioProbe(); probe.delay = 150_000
        let sound = TapSound(driverFactory: { _, change in ProbeAudioDriver(probe, changed: change) })
        let start = Date()
        sound.warm(); sound.play()
        #expect(Date().timeIntervalSince(start) < 0.1)
        await sound.drain()
        #expect(probe.recorded.contains("background:start"))
        #expect(probe.recorded.contains("background:play"))
        #expect(!probe.recorded.contains(where: { $0.hasPrefix("main:") }))
        sound.silence(); await sound.drain()
        #expect(probe.recorded.last == "background:stop")
    }

    @Test func configurationChangesRebuildInsteadOfResumingTheOldEngine() async {
        let probe = AudioProbe()
        let sound = TapSound(driverFactory: { _, change in ProbeAudioDriver(probe, changed: change) })
        sound.warm(); await sound.drain()
        probe.changed(); await sound.drain()
        sound.play(); await sound.drain()
        #expect(probe.recorded.filter { $0 == "background:start" }.count == 2)
        #expect(probe.recorded.contains("background:stop"))
        sound.silence(); await sound.drain()
    }

    @Test func missingRenderDiscardsTheBrokenDriver() async throws {
        let probe = AudioProbe(); probe.render = false
        let sound = TapSound(.click, renderGrace: 0.01, driverFactory: { _, change in ProbeAudioDriver(probe, changed: change) })
        sound.play(); await sound.drain()
        try await Task.sleep(nanoseconds: 300_000_000)
        await sound.drain()
        #expect(probe.recorded.contains("background:stop"))
        sound.warm(); await sound.drain()
        #expect(probe.recorded.filter { $0 == "background:start" }.count == 2)
        sound.silence(); await sound.drain()
    }

    @Test func mutingDoesNotStartAnEngine() async {
        let probe = AudioProbe()
        let sound = TapSound(driverFactory: { _, change in ProbeAudioDriver(probe, changed: change) })
        sound.enabled = false
        sound.warm(); sound.play(); await sound.drain()
        #expect(probe.recorded.isEmpty)
    }

    @Test func aQueuedTapIsCancelledWhileTheDeviceIsBlocked() async throws {
        let probe = AudioProbe(); probe.delay = 150_000
        let sound = TapSound(driverFactory: { _, change in ProbeAudioDriver(probe, changed: change) })
        sound.warm()
        try await Task.sleep(nanoseconds: 30_000_000)
        sound.play()
        sound.enabled = false
        await sound.drain()
        #expect(!probe.recorded.contains("background:play"))
    }
    @Test func mutingDuringTheFirstPlaybackStartupPreventsThatPlayback() async {
        let probe = AudioProbe(), release = DispatchSemaphore(value: 0)
        let sound = TapSound(driverFactory: { _, change in ProbeAudioDriver(probe, changed: change) })
        defer { release.signal() }
        await withCheckedContinuation { (started: CheckedContinuation<Void, Never>) in
            probe.blockStart = { started.resume(); release.wait() }
            sound.play()
        }
        sound.enabled = false
        release.signal()
        await sound.drain()
        #expect(!probe.recorded.contains("background:play"))
    }
}
