import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct TapSwingTests {
    @Test func windUpStrikesAndSettlesWithoutChangingPointerFollow() {
        var swing = TapSwing()
        swing.begin(at: 0, range: 1, reduceMotion: false)
        #expect(swing.active && swing.contactDelay == 0.22)
        let lift = swing.pose(at: 0.13, held: true)
        #expect(lift.tipY > 0 && lift.press < 0)
        let contact = swing.pose(at: 0.22, held: true)
        #expect(contact.press == 1 && contact.tipY == 0 && contact.tilt == 0)
        swing.release(at: 0.3)
        let settling = swing.pose(at: 0.42, held: false)
        #expect(settling.press > 0 && settling.press < 1)
        _ = swing.pose(at: 3, held: false)
        #expect(!swing.active)
    }
    @Test func draggingLandsImmediatelyAndReduceMotionKeepsTheOriginalTap() {
        var swing = TapSwing()
        swing.begin(at: 10, range: 2, reduceMotion: false)
        swing.reachContact(at: 10.03)
        #expect(swing.pose(at: 10.03, held: true).press == 1)
        swing.begin(at: 20, range: 2, reduceMotion: true)
        #expect(!swing.active && swing.contactDelay == 0)
        swing.begin(at: 30, range: 0, reduceMotion: false)
        #expect(!swing.active && swing.pose(at: 30.1, held: true).tipY == 0)
    }
    @Test func contactSoundCannotRepeatOrSurviveCancellation() async throws {
        let feedback = TapContactFeedback()
        var old = 0, current = 0
        feedback.schedule(after: 0.02) { old += 1 }
        feedback.cancel()
        feedback.schedule(after: 0.02) { current += 1 }
        feedback.reachContact()
        #expect(current == 1 && !feedback.pending)
        try await Task.sleep(nanoseconds: 60_000_000)
        #expect(old == 0 && current == 1)
    }
}
