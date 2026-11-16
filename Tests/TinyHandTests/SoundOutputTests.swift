import Foundation
import AVFoundation
import Testing
@testable import TinyHand

private final class OutputProbe {
    struct Event {
        let kind: String
        let gain: Float?
        let onMain: Bool
    }
    private let lock = NSLock()
    private var events: [Event] = []
    private var configurationChanges: [() -> Void] = []
    private var pending = 0
    var blockStart: (() -> Void)?
    var blockPlay: (() -> Void)?
    var rendersImmediately = true
    func note(_ kind: String, gain: Float? = nil) {
        lock.withLock { events.append(Event(kind: kind, gain: gain, onMain: Thread.isMainThread)) }
    }
    var recorded: [Event] { lock.withLock { events } }
    var plays: Int { recorded.filter { $0.kind == "play" }.count }
    var gains: [Float] { recorded.compactMap(\.gain) }
    var scheduledPlayback: Int { lock.withLock { pending } }
    func schedule() {
        lock.withLock {
            events.append(Event(kind: "play", gain: nil, onMain: Thread.isMainThread))
            if !rendersImmediately { pending += 1 }
        }
    }
    func cancelScheduledPlayback() { lock.withLock { pending = 0 } }
    func rememberConfigurationChange(_ callback: @escaping () -> Void) {
        lock.withLock { configurationChanges.append(callback) }
    }
    func changeFirstDriverConfiguration() {
        let callback = lock.withLock { configurationChanges.first }
        callback?()
    }
}

private final class OutputDriver: TapAudioDriver {
    let probe: OutputProbe
    var isRunning = false
    init(_ probe: OutputProbe) { self.probe = probe }
    func start() throws { probe.note("start"); probe.blockStart?(); isRunning = true }
    func setGain(_ gain: Float) { probe.note("gain", gain: gain) }
    func play(_ buffer: AVAudioPCMBuffer, rendered: @escaping () -> Void) {
        probe.schedule(); probe.blockPlay?()
        if probe.rendersImmediately { rendered() }
    }
    func stop() { probe.note("stop"); probe.cancelScheduledPlayback(); isRunning = false }
}

@Suite(.serialized) @MainActor struct SoundOutputTests {
    private func player(_ probe: OutputProbe) -> TapSound {
        // Queue-ordering fixtures intentionally leave buffers unrendered. Real
        // watchdog and idle deadlines are covered separately by AudioTests.
        TapSound(.click, deadlineScheduler: { @Sendable _, _ in }, driverFactory: { _, changed in
            probe.rememberConfigurationChange(changed)
            return OutputDriver(probe)
        })
    }

    @Test func initialOutputPreservesFullVolumeAndExistingEnabledSettings() {
        #expect(SoundOutputConfiguration().volume == 1)
        #expect(!SoundOutputConfiguration().muted)
        #expect(SoundOutputConfiguration().gain == 1)
        #expect(SoundOutputConfiguration(volume: 0.5, muted: true).gain == 0)
        #expect(!SoundOutputConfiguration(volume: 0).audible)
        #expect(SoundOutputConfiguration(volume: .nan).volume == 1)
        #expect(SoundOutputConfiguration(volume: 2).volume == 1)
        #expect(SoundOutputConfiguration(volume: -1).volume == 0)
    }

    @Test func automationOutputValidationRejectsBooleansNumbersAndOutOfRangeValues() throws {
        let invalidVolume: [Any] = [true, false, "0.5", NSNull(), -0.01, 1.01, Double.nan, Double.infinity, [0.5]]
        for value in invalidVolume {
            #expect(throws: (any Error).self) { try SoundOutputPatch(volume: value, muted: nil) }
        }
        let invalidMute: [Any] = [0, 1, 0.0, "false", NSNull(), [true]]
        for value in invalidMute {
            #expect(throws: (any Error).self) { try SoundOutputPatch(volume: nil, muted: value) }
        }
        let patch = try SoundOutputPatch(volume: 0.25, muted: true)
        #expect(patch.volume == 0.25 && patch.muted == true)
        let absent = try SoundOutputPatch(volume: nil, muted: nil)
        #expect(absent.volume == nil && absent.muted == nil)
    }

    @Test func gainAppliesToNewAndAlreadyRunningDriversOnlyOnTheAudioQueue() async {
        let probe = OutputProbe()
        let tested = player(probe)
        tested.setOutput(SoundOutputConfiguration(volume: 0.25))
        tested.play(); await tested.drain()
        #expect(probe.plays == 1)
        #expect(probe.gains.last == 0.25)
        tested.setOutput(SoundOutputConfiguration(volume: 0.75))
        await tested.drain()
        #expect(probe.gains.last == 0.75)
        #expect(probe.recorded.filter { $0.kind == "start" }.count == 1)
        #expect(!probe.recorded.contains(where: { $0.onMain }))
        tested.silence(); await tested.drain()
    }

    @Test func muteStopsCurrentAudioAndUnmuteNeverReplaysIt() async {
        let probe = OutputProbe(), sound = player(probe)
        sound.setOutput(SoundOutputConfiguration(volume: 0.4))
        sound.play(); await sound.drain()
        sound.setOutput(SoundOutputConfiguration(volume: 0.4, muted: true))
        sound.play(); sound.warm(); await sound.drain()
        #expect(probe.plays == 1)
        #expect(probe.recorded.last?.kind == "stop")
        sound.setOutput(SoundOutputConfiguration(volume: 0.4))
        await sound.drain()
        #expect(probe.plays == 1)
        sound.play(); await sound.drain()
        #expect(probe.plays == 2 && probe.gains.last == 0.4)
        sound.silence(); await sound.drain()
    }

    @Test func zeroVolumeAndMasterMuteNeverStartAnAudioDevice() async {
        for output in [SoundOutputConfiguration(volume: 0), SoundOutputConfiguration(muted: true)] {
            let probe = OutputProbe(), sound = player(probe)
            sound.setOutput(output)
            sound.warm(); sound.play(); await sound.drain()
            #expect(probe.recorded.isEmpty)
        }
    }

    @Test(arguments: [true, false])
    func inaudibleTransitionCancelsScheduledAudioEvenWhenOutputIsRestoredBeforeQueueDrains(masterMute: Bool) async {
        let probe = OutputProbe(), sound = player(probe)
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        probe.rendersImmediately = false
        sound.setOutput(SoundOutputConfiguration(volume: 0.4))
        // Hold the serial queue after the driver has scheduled a buffer. Every
        // output change below must arrive before either output closure can run.
        await withCheckedContinuation { (scheduled: CheckedContinuation<Void, Never>) in
            probe.blockPlay = { scheduled.resume(); release.wait() }
            sound.play()
        }
        #expect(probe.scheduledPlayback == 1)
        sound.play() // A pending press from before mute must also be cancelled.
        sound.setOutput(masterMute ? SoundOutputConfiguration(volume: 0.4, muted: true)
                                   : SoundOutputConfiguration(volume: 0))
        sound.play(); sound.warm() // Calls during silence cannot replay later.
        sound.setOutput(SoundOutputConfiguration(volume: 0.3))
        sound.setOutput(SoundOutputConfiguration(volume: 0.65))
        probe.blockPlay = nil
        release.signal()
        await sound.drain()
        #expect(probe.plays == 1)
        #expect(probe.scheduledPlayback == 0)
        #expect(probe.recorded.filter { $0.kind == "stop" }.count == 1)
        #expect(probe.recorded.filter { $0.kind == "start" }.count == 1)
        await sound.drain()
        #expect(probe.plays == 1 && probe.scheduledPlayback == 0)

        sound.play(); await sound.drain()
        #expect(probe.plays == 2 && probe.scheduledPlayback == 1)
        #expect(probe.recorded.filter { $0.kind == "start" }.count == 2)
        #expect(probe.gains.last == 0.65)
        // The discarded driver's delayed notification cannot tear down its replacement.
        probe.changeFirstDriverConfiguration(); await sound.drain()
        #expect(probe.scheduledPlayback == 1)
        #expect(probe.recorded.filter { $0.kind == "stop" }.count == 1)
        #expect(!probe.recorded.contains(where: { $0.onMain }))
        sound.silence(); await sound.drain()
        #expect(probe.scheduledPlayback == 0)
    }

    @Test func rapidPositiveVolumeChangesKeepLiveAudioAndApplyTheLatestGain() async {
        let probe = OutputProbe(), sound = player(probe)
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        probe.rendersImmediately = false
        await withCheckedContinuation { (scheduled: CheckedContinuation<Void, Never>) in
            probe.blockPlay = { scheduled.resume(); release.wait() }
            sound.play()
        }
        sound.setOutput(SoundOutputConfiguration(volume: 0.2))
        sound.setOutput(SoundOutputConfiguration(volume: 0.8))
        sound.setOutput(SoundOutputConfiguration(volume: 0.45))
        probe.blockPlay = nil
        release.signal()
        await sound.drain()
        #expect(probe.plays == 1 && probe.scheduledPlayback == 1)
        #expect(probe.gains.last == 0.45)
        #expect(probe.recorded.filter { $0.kind == "start" }.count == 1)
        #expect(!probe.recorded.contains { $0.kind == "stop" || $0.onMain })
        sound.silence(); await sound.drain()
    }

    @Test(arguments: [true, false])
    func masterMuteCancelsPlaybackDuringBlockedStartupAndPendingPresses(restoreBeforeDrain: Bool) async {
        for output in [SoundOutputConfiguration(muted: true), SoundOutputConfiguration(volume: 0)] {
            let probe = OutputProbe(), sound = player(probe)
            let release = DispatchSemaphore(value: 0)
            await withCheckedContinuation { (started: CheckedContinuation<Void, Never>) in
                probe.blockStart = { started.resume(); release.wait() }
                sound.play()
            }
            sound.play()
            sound.setOutput(output)
            if restoreBeforeDrain { sound.setOutput(SoundOutputConfiguration(volume: 0.6)) }
            release.signal()
            await sound.drain()
            #expect(probe.plays == 0)
            #expect(probe.recorded.contains { $0.kind == "stop" })
            #expect(!probe.recorded.contains(where: { $0.onMain }))
        }
    }

    @Test func changingOutputCancelsOldTicketsAndFreshPlaybackUsesTheNewGain() async {
        let probe = OutputProbe(), sound = player(probe)
        let release = DispatchSemaphore(value: 0)
        await withCheckedContinuation { (started: CheckedContinuation<Void, Never>) in
            probe.blockStart = { started.resume(); release.wait() }
            sound.play()
        }
        sound.setOutput(SoundOutputConfiguration(volume: 0.2))
        release.signal()
        await sound.drain()
        #expect(probe.plays == 0)
        probe.blockStart = nil
        sound.play(); await sound.drain()
        #expect(probe.plays == 1 && probe.gains.last == 0.2)
        sound.silence(); await sound.drain()
    }

    @Test func previewNeverChangesSavedChoiceEnablesTapsOrOverridesMasterMute() async throws {
        #expect(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        Preferences.resetAll()
        Preferences.handSound = false
        Preferences.tapSound = .wood
        Preferences.soundVolume = 0.35
        try Preferences.updatePointer("robot") { $0.sound = .quack; $0.soundEnabled = false }
        let saved = try PointerConfigurationDocument.load(from: Preferences.storage).encoded()
        let probe = OutputProbe(), sound = player(probe), preview = SoundAudition(sound: sound)
        preview.preview(.coin, output: Preferences.soundOutput)
        #expect(!Preferences.handSound && Preferences.tapSound == .wood)
        #expect(Preferences.pointerConfiguration(for: "robot").sound == .quack)
        #expect(!Preferences.pointerConfiguration(for: "robot").soundEnabled)
        let after = try PointerConfigurationDocument.load(from: Preferences.storage).encoded()
        #expect(saved == after)
        Preferences.soundMuted = true
        #expect(Preferences.soundVolume == 0.35 && Preferences.tapSound == .wood)
        // All preference assertions run synchronously. Other test suites may use
        // the shared isolated app suite while this test awaits its fake driver.
        Preferences.resetAll()
        await sound.drain()
        #expect(probe.plays == 1 && probe.gains.last == 0.35)
        let muted = SoundOutputConfiguration(volume: 0.35, muted: true)
        preview.updateOutput(muted)
        preview.preview(.pew, output: muted)
        await sound.drain()
        #expect(probe.plays == 1)
        preview.stop(); await sound.drain()
    }

    @Test func previewCancellationDuringStartupCannotPlayLater() async {
        let probe = OutputProbe(), sound = player(probe), preview = SoundAudition(sound: sound)
        let release = DispatchSemaphore(value: 0)
        await withCheckedContinuation { (started: CheckedContinuation<Void, Never>) in
            probe.blockStart = { started.resume(); release.wait() }
            preview.preview(.click, output: SoundOutputConfiguration())
        }
        preview.stop()
        release.signal()
        await sound.drain()
        #expect(probe.plays == 0)
    }

    @Test func outputReadbackDistinguishesSavedEnableFromEffectiveMuteAndVolume() {
        let muted = SoundOutputConfiguration(volume: 0.7, muted: true).state(enabled: true)
        #expect(muted["pointerEnabled"] as? Bool == true)
        #expect(muted["audible"] as? Bool == false && muted["gain"] as? Double == 0)
        #expect(muted["volume"] as? Double == 0.7 && muted["status"] as? String == "Master muted")
        let disabled = SoundOutputConfiguration(volume: 0.7).state(enabled: false)
        #expect(disabled["audible"] as? Bool == false && disabled["status"] as? String == "Tap sound off")
        #expect(SoundOutputConfiguration(volume: 0).status(enabled: true) == "Volume is zero")
        #expect(SoundOutputConfiguration(volume: 0.7).status(enabled: true) == "On at 70%")
    }

    @Test func resetRestoresOutputWithoutChangingTheInitialLaserPolicy() {
        #expect(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        Preferences.soundMuted = true; Preferences.soundVolume = 0.2
        Preferences.resetAll()
        #expect(Preferences.soundOutput == SoundOutputConfiguration())
        #expect(!Preferences.pointerConfiguration(for: "laser").soundEnabled)
        #expect(Preferences.pointerConfiguration(for: "spotlight").soundEnabled)
    }
}
