import Foundation
import CoreGraphics

/// The optional visual tap, independent of pointer following and event delivery.
/// Timing follows tumaranja/tinyhand b21dc52; zero retains the existing tap.
struct TapSwing {
    struct Pose {
        var press: CGFloat = 0
        var poke: CGFloat = 0
        var tilt: CGFloat = 0
        var tipX: CGFloat = 0
        var tipY: CGFloat = 0
        var gripX: CGFloat = 0
        var gripY: CGFloat = 0
    }
    static let windUp: TimeInterval = 0.13
    static let strike: TimeInterval = 0.22
    private var start: TimeInterval?
    private var released: TimeInterval = 0
    private var range: CGFloat = 0
    var active: Bool { start != nil }
    var contactDelay: TimeInterval { active ? Self.strike : 0 }

    mutating func begin(at time: TimeInterval, range: CGFloat, reduceMotion: Bool) {
        self.range = min(2, max(0, range))
        start = !reduceMotion && self.range > 0.001 ? time : nil
        released = time
    }
    mutating func release(at time: TimeInterval) { released = time }
    mutating func reachContact(at time: TimeInterval) { if start != nil { start = time - Self.strike } }
    mutating func cancel() { start = nil }
    mutating func pose(at time: TimeInterval, held: Bool) -> Pose {
        guard let start else { return Pose() }
        let elapsed = max(0, time - start)
        func lifted(_ amount: CGFloat, press: CGFloat) -> Pose {
            // A bounded lift remains readable near display edges and with large hands.
            let x = 0.02 * range * amount, y = 0.12 * range * amount
            return Pose(press: press, poke: 0.02 * range * amount, tilt: -0.03 * range * amount,
                        tipX: x, tipY: y, gripX: 0.45 * x, gripY: 0.45 * y)
        }
        if elapsed < Self.windUp {
            let amount = 1 - pow(1 - CGFloat(elapsed / Self.windUp), 3)
            return lifted(amount, press: -0.6 * amount)
        }
        if elapsed < Self.strike {
            let amount = pow(CGFloat((elapsed - Self.windUp) / (Self.strike - Self.windUp)), 2)
            return lifted(1 - amount, press: -0.6 + 1.6 * amount)
        }
        if held { return Pose(press: 1) }
        let press = CGFloat(exp(-max(0, time - max(start + Self.strike, released)) / 0.12))
        if press < 0.001 { self.start = nil; return Pose() }
        return Pose(press: press)
    }
}
