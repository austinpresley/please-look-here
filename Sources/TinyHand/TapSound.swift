import AppKit
import AVFoundation

enum TapSoundChoice: String, CaseIterable {
    case thock, click, tock, clack, typewriter, snap, wood, pop, boop, blip, coin, pew, squeak, quack, chirp

    var title: String {
        switch self {
        case .thock: return "Thock"
        case .click: return "Click"
        case .pop: return "Pop"
        case .wood: return "Wood block"
        case .boop: return "Boop"
        case .squeak: return "Squeak"
        case .tock: return "Tock"
        case .clack: return "Clack"
        case .typewriter: return "Typewriter"
        case .snap: return "Snap"
        case .blip: return "Blip"
        case .coin: return "Coin"
        case .pew: return "Pew"
        case .quack: return "Quack"
        case .chirp: return "Chirp"
        }
    }
}

/// The interface keeps blocking audio-device operations off the main thread.
/// Based on nilbuild/tinyhand ca1550d, with an injectable driver for recovery checks.
protocol TapAudioDriver: AnyObject {
    var isRunning: Bool { get }
    func start() throws
    func play(_ buffer: AVAudioPCMBuffer, rendered: @escaping () -> Void)
    func stop()
}

private final class EngineTapAudioDriver: TapAudioDriver {
    private let engine = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private var next = 0
    private var observer: NSObjectProtocol?

    init(format: AVAudioFormat, configurationChanged: @escaping () -> Void) {
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            nodes.append(player)
        }
        for unit in nodes.map(\.auAudioUnit) + [engine.mainMixerNode.auAudioUnit]
        where !unit.renderResourcesAllocated && unit.maximumFramesToRender < 4096 {
            unit.maximumFramesToRender = 4096
        }
        observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange,
            object: engine, queue: nil) { @Sendable _ in configurationChanged() }
    }

    var isRunning: Bool { engine.isRunning }
    func start() throws { engine.prepare(); try engine.start() }
    func play(_ buffer: AVAudioPCMBuffer, rendered: @escaping () -> Void) {
        let player = nodes[next % nodes.count]
        next += 1
        player.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataRendered) { @Sendable _ in rendered() }
        if !player.isPlaying { player.play() }
    }
    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer); self.observer = nil }
        engine.stop()
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}

// AVAudioEngine is not Sendable. Every driver/choice mutation is private to our
// serial queue; the only caller-shared state is guarded by Gate's lock. This
// audited wrapper is the transfer point for legacy audio callbacks, not the driver.
final class TapSound: @unchecked Sendable {
    typealias DriverFactory = (AVAudioFormat, @escaping () -> Void) -> TapAudioDriver
    private final class Receipt {
        private let lock = NSLock()
        private var value = false
        func finish() { lock.withLock { value = true } }
        var rendered: Bool { lock.withLock { value } }
    }
    private final class Gate {
        private let lock = NSLock()
        private var allowed = true
        private var generation = 0
        var enabled: Bool {
            get { lock.withLock { allowed } }
            set { lock.withLock { if allowed != newValue { allowed = newValue; generation += 1 } } }
        }
        func ticket() -> Int? { lock.withLock { allowed ? generation : nil } }
        func accepts(_ ticket: Int) -> Bool { lock.withLock { allowed && generation == ticket } }
        func cancel() { lock.withLock { generation += 1 } }
    }
    private let gate = Gate()
    private let queue = DispatchQueue(label: "Look Here Please tap audio", qos: .userInitiated)
    private let buffers: [TapSoundChoice: AVAudioPCMBuffer]
    private let format: AVAudioFormat
    private let factory: DriverFactory
    private let renderGrace: TimeInterval
    // The serial queue owns these fields and every driver operation.
    private var choice: TapSoundChoice
    private var driver: TapAudioDriver?
    private var generation = 0
    private var idleStop: DispatchWorkItem?
    var enabled: Bool {
        get { gate.enabled }
        set { gate.enabled = newValue; if !newValue { silence() } }
    }

    init(_ choice: TapSoundChoice = Preferences.tapSound, renderGrace: TimeInterval = 1,
         driverFactory: @escaping DriverFactory = { EngineTapAudioDriver(format: $0, configurationChanged: $1) }) {
        self.choice = choice
        self.factory = driverFactory
        self.renderGrace = renderGrace
        var loaded: [TapSoundChoice: AVAudioPCMBuffer] = [:]
        for item in TapSoundChoice.allCases { if let buffer = Self.read(item) { loaded[item] = buffer } }
        buffers = loaded
        format = loaded.values.first?.format ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    }

    func load(_ choice: TapSoundChoice) { queue.async { @Sendable [weak self] in self?.choice = choice } }
    func warm() {
        guard let ticket = gate.ticket() else { return }
        queue.async { @Sendable [weak self] in
            guard let self, self.gate.accepts(ticket) else { return }
            _ = self.start()
        }
    }
    func play() {
        guard let ticket = gate.ticket() else { return }
        queue.async { @Sendable [weak self] in
            guard let self, self.gate.accepts(ticket) else { return }
            self.playNow()
        }
    }
    func silence() {
        gate.cancel()
        queue.async { @Sendable [weak self] in self?.teardown() }
    }

    private func playNow() {
        guard let buffer = buffers[choice], start(), let driver else { return }
        let receipt = Receipt(), token = generation
        driver.play(buffer) { @Sendable in receipt.finish() }
        let duration = Double(buffer.frameLength) / buffer.format.sampleRate
        queue.asyncAfter(deadline: .now() + duration + renderGrace) { @Sendable [weak self] in
            guard let self, self.generation == token, !receipt.rendered else { return }
            Log.write("Tap did not render; discarding the audio engine")
            self.teardown()
        }
    }
    @discardableResult private func start() -> Bool {
        idleStop?.cancel()
        let idle = DispatchWorkItem { @Sendable [weak self] in self?.teardown() }
        idleStop = idle
        queue.asyncAfter(deadline: .now() + 30, execute: idle)
        if let driver, driver.isRunning { return true }
        teardown(cancelIdle: false)
        let token = generation
        let candidate = factory(format) { @Sendable [weak self] in
            self?.queue.async { @Sendable [weak self] in
                guard let self, self.generation == token else { return }
                self.teardown()
            }
        }
        do { try candidate.start(); driver = candidate; return true }
        catch { candidate.stop(); Log.write("Tap audio could not start: \(error.localizedDescription)"); return false }
    }
    private func teardown(cancelIdle: Bool = true) {
        generation += 1
        if cancelIdle { idleStop?.cancel(); idleStop = nil }
        driver?.stop()
        driver = nil
    }
    /// An asynchronous fence, also useful for deterministic local background smoke checks.
    func drain() async { await withCheckedContinuation { continuation in queue.async { continuation.resume() } } }

    deinit {
        idleStop?.cancel()
        let previous = driver
        queue.async { @Sendable in previous?.stop() }
    }

    private static func read(_ choice: TapSoundChoice) -> AVAudioPCMBuffer? {
        let name = "tap_\(choice.rawValue)"
        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "wav"),
            exeDir.appendingPathComponent("\(name).wav"),
            exeDir.appendingPathComponent("assets/sounds/\(name).wav"),
            URL(fileURLWithPath: "assets/sounds/\(name).wav"),
        ].compactMap { $0 }
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            guard let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                continue
            }
            if (try? file.read(into: buffer)) != nil {
                return buffer
            }
        }
        return nil
    }
}
