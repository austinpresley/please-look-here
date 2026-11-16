import Foundation
import CoreFoundation

struct SoundOutputPatch {
    let volume: Double?
    let muted: Bool?

    init(volume: Any?, muted: Any?) throws {
        if let volume {
            guard let number = volume as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.doubleValue.isFinite, (0...1).contains(number.doubleValue) else {
                throw PointerConfigurationError.invalid("Sound volume must be a finite number between 0 and 1.")
            }
            self.volume = number.doubleValue
        } else { self.volume = nil }
        if let muted {
            guard let number = muted as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
                throw PointerConfigurationError.invalid("Master mute must be a boolean.")
            }
            self.muted = number.boolValue
        } else { self.muted = nil }
    }
}

/// App output is independent of the saved pointer sound and enabled overrides.
struct SoundOutputConfiguration: Equatable {
    let volume: Double
    let muted: Bool

    init(volume: Double = 1, muted: Bool = false) {
        self.volume = volume.isFinite ? min(1, max(0, volume)) : 1
        self.muted = muted
    }

    var gain: Float { muted ? 0 : Float(volume) }
    var audible: Bool { gain > 0 }

    func status(enabled: Bool) -> String {
        if muted { return "Master muted" }
        if volume == 0 { return "Volume is zero" }
        return enabled ? "On at \(Int((volume * 100).rounded()))%" : "Tap sound off"
    }

    func state(enabled: Bool) -> [String: Any] {
        ["volume": volume, "masterMuted": muted, "pointerEnabled": enabled,
         "audible": enabled && audible, "gain": enabled ? Double(gain) : 0,
         "status": status(enabled: enabled)]
    }
}

/// Preview owns a separate player. It never writes preferences or enables taps.
/// Output changes cancel it through the same gate as live pointer audio.
final class SoundAudition {
    private let sound: TapSound
    init(sound: TapSound = TapSound()) { self.sound = sound }

    func preview(_ choice: TapSoundChoice, output: SoundOutputConfiguration) {
        sound.setOutput(output)
        sound.load(choice)
        sound.play()
    }

    func updateOutput(_ output: SoundOutputConfiguration) { sound.setOutput(output) }
    func stop() { sound.silence() }
}

extension Preferences {
    static var soundOutput: SoundOutputConfiguration {
        SoundOutputConfiguration(volume: soundVolume, muted: soundMuted)
    }
}
