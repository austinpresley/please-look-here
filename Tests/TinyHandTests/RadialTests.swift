import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct RadialTests {
    private func input(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                       nativeKeyState: @escaping (CGKeyCode) -> Bool = { _ in false }) -> RadialInput {
        RadialInput(clock: clock, nativeKeyState: nativeKeyState, scheduleHold: { _, _ in })
    }
    private func event(_ type: CGEventType, flags: CGEventFlags = [], button: Int64 = 0, key: Int64 = 0, repeatDown: Bool = false) -> CGEvent {
        let e = CGEvent(source: nil)!
        e.type = type; e.flags = flags
        e.setIntegerValueField(.keyboardEventAutorepeat, value: repeatDown ? 1 : 0)
        if type == .keyDown || type == .keyUp { e.setIntegerValueField(.keyboardEventKeycode, value: key) }
        else { e.setIntegerValueField(.mouseEventButtonNumber, value: button) }
        return e
    }
    @Test func triggerStartsUnassignedClearsAndPreservesOtherShortcuts() {
        Preferences.resetAll()
        #expect(Preferences.radialTrigger == nil)
        let shortcut = Shortcut(keyCode: 8, modifiers: 2048, display: "⌥C")
        Preferences.setShortcut(shortcut, for: .pen)
        Preferences.radialTrigger = .option
        Preferences.radialTrigger = nil
        #expect(Preferences.shortcut(for: .pen) == shortcut)
        #expect(Preferences.storage.object(forKey: "radialTrigger") == nil)
        Preferences.radialTrigger = .control; Preferences.resetAll()
        #expect(Preferences.radialTrigger == nil)
    }
    @Test func noAssignmentOrDeniedContextNeverClaimsInput() {
        for trigger: RadialTrigger? in [nil, .option] {
            let r = input(); r.configure(trigger: trigger, eligible: trigger == nil)
            for t: CGEventType in [.flagsChanged, .leftMouseDown, .leftMouseUp, .keyDown, .keyUp] {
                #expect(!r.handle(t, event: event(t, flags: .maskAlternate), dragging: false))
            }
        }
    }
    @Test func modifiersAndOrdinaryKeyboardPassUnchangedAndLatchClosed() {
        for trigger in RadialTrigger.allCases {
            let r = input(); r.configure(trigger: trigger, eligible: true)
            let flags = event(.flagsChanged, flags: trigger.flag)
            #expect(!r.handle(.flagsChanged, event: flags, dragging: false))
            #expect(flags.flags == trigger.flag)
            let key = event(.keyDown, flags: trigger.flag, key: 8)
            #expect(!r.handle(.keyDown, event: key, dragging: false))
            #expect(key.flags == trigger.flag)
            #expect(!r.handle(.keyUp, event: event(.keyUp, flags: trigger.flag, key: 8), dragging: false))
            #expect(!r.handle(.flagsChanged, event: flags, dragging: false))
            #expect(!r.handle(.leftMouseDown, event: event(.leftMouseDown), dragging: false))
            #expect(r.diagnostics["open"] as? Bool == false)
        }
    }
    @Test func escapeAndAllMouseButtonsDrainAfterDismissalAndDisable() {
        for button: Int64 in [0, 1, 2, 4] {
            let r = input(); r.configure(trigger: .option, eligible: true)
            _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
            let down: CGEventType = button == 0 ? .leftMouseDown : button == 1 ? .rightMouseDown : .otherMouseDown
            let up: CGEventType = button == 0 ? .leftMouseUp : button == 1 ? .rightMouseUp : .otherMouseUp
            #expect(r.handle(down, event: event(down, button: button), dragging: false))
            r.configure(trigger: nil, eligible: false); r.end(sessionID: r.currentSessionID!)
            #expect(r.needsTap)
            #expect(r.handle(up, event: event(up, button: button), dragging: false))
            #expect(!r.needsTap)
        }
        let r = input(); r.configure(trigger: .shift, eligible: true)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskShift), dragging: false)
        r.advanceHold(flags: .maskShift, dragging: false, now: .greatestFiniteMagnitude)
        #expect(r.handle(.keyDown, event: event(.keyDown, key: 53), dragging: false))
        r.configure(trigger: nil, eligible: false)
        #expect(r.handle(.keyUp, event: event(.keyUp, key: 53), dragging: false))
        #expect(!r.needsTap)
    }
    @Test func existingDragAndExtraModifiersRequireFreshGesture() {
        let r = input(); r.configure(trigger: .option, eligible: true)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: true)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(r.diagnostics["open"] as? Bool == false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(r.diagnostics["open"] as? Bool == false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged), dragging: false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: [.maskAlternate, .maskCommand]), dragging: false)
        #expect(r.diagnostics["open"] as? Bool == false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged), dragging: false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(r.diagnostics["open"] as? Bool == true)
        r.end(sessionID: r.currentSessionID!)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(r.diagnostics["open"] as? Bool == false)
    }
    @Test func enablingWhileModifierIsAlreadyHeldRequiresReleaseAndFreshPress() {
        let r = input()
        r.configure(trigger: .option, eligible: true, flags: .maskAlternate)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(r.diagnostics["open"] as? Bool == false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged), dragging: false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(r.diagnostics["open"] as? Bool == true)
    }
    @Test func overlappingButtonsStayOwnedUntilEveryClaimedRelease() {
        let r = input(); r.configure(trigger: .option, eligible: true)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(r.handle(.leftMouseDown, event: event(.leftMouseDown), dragging: false))
        r.end(sessionID: r.currentSessionID!) // UI has selected and closed, but the first button is still down.
        #expect(r.handle(.rightMouseDown, event: event(.rightMouseDown, button: 1), dragging: true))
        #expect(r.handle(.leftMouseUp, event: event(.leftMouseUp), dragging: true))
        #expect(r.handle(.rightMouseUp, event: event(.rightMouseUp, button: 1), dragging: false))
        #expect((r.diagnostics["buttons"] as? [Int64])?.isEmpty == true)
    }
    @Test func radialClaimPrecedesAnnotationRoutingAndDrainsAfterShutdown() {
        let tap = InputTap(radial: input())
        tap.setActive(true)
        tap.radial.configure(trigger: .option, eligible: true)
        #expect(tap.handle(type: .flagsChanged, event: event(.flagsChanged, flags: .maskAlternate)) != nil)
        tap.radial.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(tap.handle(type: .leftMouseDown, event: event(.leftMouseDown, flags: .maskAlternate)) == nil)
        #expect((tap.diagnostics["capturedButtons"] as? [Int64])?.isEmpty == true)
        tap.setActive(false)
        tap.radial.configure(trigger: nil, eligible: false)
        #expect(tap.handle(type: .leftMouseUp, event: event(.leftMouseUp)) == nil)
        #expect(!tap.radial.needsTap)
    }
    @Test(arguments: ["cancel", "clear", "deactivate"])
    func claimedEscapeRepeatsDrainThroughInputTap(_ transition: String) {
        let tap = InputTap(radial: input())
        tap.setActive(true)
        tap.radial.configure(trigger: .option, eligible: true)
        #expect(tap.handle(type: .flagsChanged, event: event(.flagsChanged, flags: .maskAlternate)) != nil)
        tap.radial.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(tap.radial.diagnostics["open"] as? Bool == true)
        #expect(tap.handle(type: .keyDown, event: event(.keyDown, flags: .maskAlternate, key: 53)) == nil)
        #expect(tap.radial.diagnostics["open"] as? Bool == false)
        if transition == "clear" { tap.radial.configure(trigger: nil, eligible: false) }
        if transition == "deactivate" {
            tap.setActive(false)
            tap.radial.configure(trigger: .option, eligible: false)
        }
        #expect(tap.radial.needsTap)
        for flags: CGEventFlags in [.maskAlternate, []] {
            let repeatEvent = event(.keyDown, flags: flags, key: 53, repeatDown: true)
            #expect(repeatEvent.getIntegerValueField(.keyboardEventAutorepeat) == 1)
            #expect(tap.handle(type: .keyDown, event: repeatEvent) == nil)
            let modifierEvent = event(.flagsChanged, flags: flags)
            #expect(tap.handle(type: .flagsChanged, event: modifierEvent)?.takeUnretainedValue() === modifierEvent)
        tap.radial.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
            #expect(modifierEvent.flags == flags)
        }
        #expect(tap.handle(type: .keyUp, event: event(.keyUp, key: 53)) == nil)
        #expect((tap.radial.diagnostics["keys"] as? [Int64])?.isEmpty == true)
        tap.radial.configure(trigger: nil, eligible: false)
        #expect(!tap.radial.needsTap)
        // A new unclaimed Escape and an ordinary modified repeat pair still pass.
        for (key, repeatDown) in [(Int64(53), false), (Int64(8), true)] {
            for type: CGEventType in [.keyDown, .keyUp] {
                let ordinary = event(type, flags: .maskAlternate, key: key, repeatDown: repeatDown)
                #expect(tap.handle(type: type, event: ordinary)?.takeUnretainedValue() === ordinary)
                #expect(ordinary.flags == .maskAlternate)
            }
        }
    }
    @Test func holdDeadlineAndEarlyNativePairs() {
        for type: CGEventType in [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel] {
            var now: TimeInterval = 10
            let r = input(clock: { now }); r.configure(trigger: .option, eligible: true)
            _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
            now += 0.179
            r.advanceHold(flags: .maskAlternate, dragging: false)
            #expect(r.diagnostics["pending"] as? Bool == true)
            #expect(r.diagnostics["open"] as? Bool == false)
            #expect(!r.handle(type, event: event(type, flags: .maskAlternate, button: 4, key: 8), dragging: false))
            now += 1
            r.advanceHold(flags: .maskAlternate, dragging: false)
            #expect(r.diagnostics["open"] as? Bool == false)
            let up: CGEventType = type == .keyDown ? .keyUp : type == .leftMouseDown ? .leftMouseUp : type == .rightMouseDown ? .rightMouseUp : .otherMouseUp
            #expect(!r.handle(up, event: event(up, flags: .maskAlternate, button: 4, key: 8), dragging: false))
        }
        var now: TimeInterval = 0
        let r = input(clock: { now }); r.configure(trigger: .option, eligible: true)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        now = 0.179; r.advanceHold(flags: .maskAlternate, dragging: false)
        #expect(r.diagnostics["open"] as? Bool == false)
        now = 0.180; r.advanceHold(flags: .maskAlternate, dragging: false)
        #expect(r.diagnostics["open"] as? Bool == true)
    }
    @Test(arguments: ["release", "click", "cancel"])
    func delayedPreviousCloseCannotClearNextPendingHold(_ ending: String) async throws {
        var now: TimeInterval = 0
        let r = input(clock: { now })
        r.configure(trigger: .option, eligible: true)
        var deliveredClose = false
        var deliveredIDs: [UInt] = []
        r.onEvent = { [weak r] sessionID, event in
            deliveredIDs.append(sessionID)
            switch event {
            case .release, .click, .cancel:
                r?.end(sessionID: sessionID) // The menu's onClose callback, delayed on the main queue.
                deliveredClose = true
            default: break
            }
        }
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        let firstID = try #require(r.currentSessionID)
        now = 0.180; r.advanceHold(flags: .maskAlternate, dragging: false)
        _ = r.handle(.mouseMoved, event: event(.mouseMoved), dragging: false)
        if ending == "click" {
            #expect(r.handle(.leftMouseDown, event: event(.leftMouseDown), dragging: false))
            #expect(r.handle(.leftMouseUp, event: event(.leftMouseUp), dragging: false))
        }
        if ending == "cancel" {
            _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: [.maskAlternate, .maskShift]), dragging: false)
        }
        _ = r.handle(.flagsChanged, event: event(.flagsChanged), dragging: false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        let secondID = try #require(r.currentSessionID)
        #expect(firstID != secondID)
        #expect(r.diagnostics["pending"] as? Bool == true)
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        #expect(deliveredClose)
        #expect(deliveredIDs == [firstID, firstID, firstID]) // Open, move and terminal retain A's identity.
        #expect(r.currentSessionID == secondID)
        #expect(r.diagnostics["pending"] as? Bool == true)
        now = 0.360; r.advanceHold(flags: .maskAlternate, dragging: false)
        #expect(r.diagnostics["open"] as? Bool == true)
        r.end(sessionID: firstID)
        #expect(r.diagnostics["open"] as? Bool == true)
    }
    @Test func staleHoldTimerCannotAdvanceOrReconcileANewerGesture() throws {
        let r = input(clock: { 0 })
        r.configure(trigger: .option, eligible: true)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        let firstID = try #require(r.currentSessionID)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged), dragging: false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        let secondID = try #require(r.currentSessionID)
        for flags: CGEventFlags in [[], .maskAlternate] {
            r.advanceHold(flags: flags, dragging: false, now: 1, sessionID: firstID)
            #expect(r.diagnostics["pending"] as? Bool == true)
            #expect(r.diagnostics["held"] as? Bool == true)
            #expect(r.diagnostics["open"] as? Bool == false)
        }
        r.advanceHold(flags: .maskAlternate, dragging: false, now: 1, sessionID: secondID)
        #expect(r.diagnostics["open"] as? Bool == true)
    }
    @Test func ordinaryKeyHeldBeforeModifierPreventsOpeningAndPassesUnchanged() {
        let r = input(clock: { 0 })
        r.configure(trigger: .option, eligible: true)
        let down = event(.keyDown, key: 49) // Space precedes the modifier, before autorepeat.
        #expect(!r.handle(.keyDown, event: down, dragging: false))
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: 0.180)
        #expect(r.diagnostics["open"] as? Bool == false)
        #expect(!r.ownsPair(.keyDown, event: down))
        #expect(down.type == .keyDown && down.flags.isEmpty)
        let repeated = event(.keyDown, flags: .maskAlternate, key: 49, repeatDown: true)
        #expect(!r.handle(.keyDown, event: repeated, dragging: false))
        #expect(repeated.getIntegerValueField(.keyboardEventAutorepeat) == 1)
        #expect(repeated.flags == .maskAlternate)
        #expect(!r.handle(.keyUp, event: event(.keyUp, key: 49), dragging: false))
        r.advanceHold(flags: .maskAlternate, dragging: false, now: 1)
        #expect(r.diagnostics["open"] as? Bool == false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged), dragging: false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: 1)
        #expect(r.diagnostics["open"] as? Bool == true)
    }
    @Test(arguments: [CGKeyCode(0), 49, 53, 64, 127])
    func nativeKeyAlreadyDownBeforeTapInstallationPreventsOpening(_ key: CGKeyCode) {
        var nativeDown = true
        let r = input(clock: { 0 }, nativeKeyState: { nativeDown && $0 == key })
        r.configure(trigger: .option, eligible: true)
        // No keyDown was observed. This models enabling the tap mid-press.
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        #expect(r.diagnostics["pending"] as? Bool == false)
        nativeDown = false
        r.advanceHold(flags: .maskAlternate, dragging: false, now: 1)
        #expect(r.diagnostics["open"] as? Bool == false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged), dragging: false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        #expect(r.diagnostics["pending"] as? Bool == true)
        nativeDown = true // Also reject a down missed during the hold.
        r.advanceHold(flags: .maskAlternate, dragging: false, now: 1)
        #expect(r.diagnostics["open"] as? Bool == false)
        #expect(!r.ownsPair(.keyUp, event: event(.keyUp, key: Int64(key))))
    }
    @Test func nativeModifierKeyStatesDoNotBlockBareModifierHold() {
        let r = input(clock: { 0 }, nativeKeyState: { (54...63).contains($0) })
        r.configure(trigger: .option, eligible: true)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: 0.180)
        #expect(r.diagnostics["open"] as? Bool == true)
    }
    @Test func nativeKeyboardPairsPassThroughInputTapWhilePreventingHold() {
        let tap = InputTap(radial: input(clock: { 0 }))
        tap.radial.configure(trigger: .option, eligible: true)
        for type: CGEventType in [.keyDown, .keyDown, .keyUp] {
            let e = event(type, flags: .maskAlternate, key: 49, repeatDown: true)
            #expect(tap.handle(type: type, event: e)?.takeUnretainedValue() === e)
            #expect(e.type == type && e.flags == .maskAlternate)
            #expect(e.getIntegerValueField(.keyboardEventAutorepeat) == 1)
            if type == .keyDown {
                _ = tap.handle(type: .flagsChanged, event: event(.flagsChanged, flags: .maskAlternate))
                tap.radial.advanceHold(flags: .maskAlternate, dragging: false, now: 1)
                #expect(tap.radial.diagnostics["open"] as? Bool == false)
            }
        }
        #expect((tap.radial.diagnostics["heldKeys"] as? [Int64])?.isEmpty == true)
        tap.radial.configure(trigger: nil, eligible: false)
        #expect(!tap.radial.needsTap)
        #expect(!tap.isInstalled)
    }
    @Test func tapReenableDiscardsMissedKeyboardReleasesButPreservesOwnership() {
        let r = input(clock: { 0 })
        _ = r.handle(.keyDown, event: event(.keyDown, key: 49), dragging: false)
        #expect(!r.needsTap) // Observation alone is never ownership.
        r.resetKeyboardObservation() // Space up happened while the tap was disabled.
        r.configure(trigger: .option, eligible: true)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: 0.180)
        #expect(r.diagnostics["open"] as? Bool == true)
        #expect(r.handle(.keyDown, event: event(.keyDown, key: 53), dragging: false))
        r.configure(trigger: nil, eligible: false)
        r.resetKeyboardObservation()
        #expect(r.needsTap)
        #expect(r.handle(.keyDown, event: event(.keyDown, key: 53, repeatDown: true), dragging: false))
        #expect(r.handle(.keyUp, event: event(.keyUp, key: 53), dragging: false))
        #expect(!r.needsTap)
    }
    @Test func missedReleaseReconcilesWhileClosedWithoutDroppingOwnedPairs() {
        let r = input(); r.configure(trigger: .option, eligible: true)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(r.handle(.leftMouseDown, event: event(.leftMouseDown), dragging: false))
        r.end(sessionID: r.currentSessionID!)
        r.configure(trigger: .option, eligible: true, flags: [])
        #expect(r.diagnostics["held"] as? Bool == false)
        #expect(r.diagnostics["reconciledReleases"] as? Int == 1)
        #expect(r.handle(.leftMouseUp, event: event(.leftMouseUp), dragging: false))
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(r.diagnostics["open"] as? Bool == true)
        // A lost release while open must cancel, never commit an old selection.
        r.configure(trigger: .option, eligible: true, flags: [])
        #expect(r.diagnostics["open"] as? Bool == false)
        #expect(r.diagnostics["held"] as? Bool == false)
    }
    @Test(arguments: ["key", "chord", "modifier", "escape", "pointer", "scroll", "pointer-cancel", "eligibility", "system", "release"])
    func pendingCancellationNeverOpensOrExecutes(_ route: String) async {
        let r = input(clock: { 0 })
        var events: [String] = []
        r.onEvent = { _, e in
            switch e {
            case .open: events.append("open")
            case .release: events.append("release")
            case .click: events.append("click")
            default: break
            }
        }
        r.configure(trigger: .option, eligible: true)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        let id = r.currentSessionID!
        #expect(r.diagnostics["pending"] as? Bool == true)
        switch route {
        case "key", "chord", "escape":
            let code: Int64 = route == "escape" ? 53 : 8
            let flags: CGEventFlags = route == "chord" ? [.maskAlternate, .maskCommand] : .maskAlternate
            #expect(r.handle(.keyDown, event: event(.keyDown, flags: flags, key: code), dragging: false) == (route == "escape"))
            #expect(r.handle(.keyUp, event: event(.keyUp, key: code), dragging: false) == (route == "escape"))
        case "modifier": _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: [.maskAlternate, .maskShift]), dragging: false)
        case "pointer":
            #expect(!r.handle(.leftMouseDown, event: event(.leftMouseDown), dragging: false))
            #expect(!r.handle(.leftMouseUp, event: event(.leftMouseUp), dragging: false))
        case "scroll": _ = r.handle(.scrollWheel, event: event(.scrollWheel), dragging: false)
        case "pointer-cancel": r.pointerCancelled()
        case "eligibility": r.configure(trigger: .option, eligible: false)
        case "system": r.suspendForSystem(releasingButton: nil, key: nil)
        default: _ = r.handle(.flagsChanged, event: event(.flagsChanged), dragging: false)
        }
        r.advanceHold(flags: .maskAlternate, dragging: false, now: 1, sessionID: id)
        _ = r.handle(.mouseMoved, event: event(.mouseMoved), dragging: false)
        _ = r.handle(.flagsChanged, event: event(.flagsChanged), dragging: false)
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        #expect(events.isEmpty)
        #expect(r.diagnostics["open"] as? Bool == false)
        #expect(r.diagnostics["pending"] as? Bool == false)
    }
    @Test func persistentTransportDrainsKeysButtonsAndRejectsOpenOverOwnedPair() async throws {
        let r = input()
        r.configure(trigger: nil, eligible: true)
        var events: [String] = []
        r.onEvent = { _, e in
            switch e {
            case .persistentOpen: events.append("open")
            case .pointerDown: events.append("down")
            case .pointerUp: events.append("up")
            case .move: events.append("move")
            case .pointerCancel: events.append("pointer-cancel")
            case .key(let key, let modifiers):
                #expect(key == .right && modifiers.isEmpty); events.append("key")
            default: break
            }
        }
        let id = try #require(r.openPersistent(at: CGPoint(x: 100, y: 100)))
        #expect(r.needsTap)
        #expect(!r.handle(.keyDown, event: event(.keyDown, flags: [.maskControl, .maskAlternate], key: 124), dragging: false))
        #expect(!r.handle(.keyUp, event: event(.keyUp, key: 124), dragging: false))
        #expect(r.handle(.keyDown, event: event(.keyDown, key: 124), dragging: false))
        #expect(r.handle(.keyUp, event: event(.keyUp, key: 124), dragging: false))
        #expect(r.handle(.leftMouseDown, event: event(.leftMouseDown), dragging: false))
        #expect(r.handle(.leftMouseDragged, event: event(.leftMouseDragged), dragging: true))
        #expect(r.handle(.leftMouseUp, event: event(.leftMouseUp), dragging: false))
        r.pointerCancelled()
        #expect(r.handle(.leftMouseDown, event: event(.leftMouseDown), dragging: false))
        // Deliver navigation while this session owns focus. Closure now rejects
        // queued activations; this test separately proves the pair still drains.
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        #expect(events == ["open", "key", "down", "move", "up", "pointer-cancel", "down"])
        r.end(sessionID: id)
        #expect(r.openPersistent(at: .zero) == nil)
        #expect(r.handle(.leftMouseUp, event: event(.leftMouseUp), dragging: false))
        #expect(!r.needsTap)
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        #expect(events == ["open", "key", "down", "move", "up", "pointer-cancel", "down"])
    }
    @Test func heldNavigationIgnoresOnlyItsInvocationModifierAndDrainsAfterClose() async throws {
        let r = input()
        r.configure(trigger: .option, eligible: true)
        var keys = 0
        r.onEvent = { _, event in if case .key(.right, []) = event { keys += 1 } }
        _ = r.handle(.flagsChanged, event: event(.flagsChanged, flags: .maskAlternate), dragging: false)
        r.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        #expect(r.handle(.keyDown, event: event(.keyDown, flags: .maskAlternate, key: 124), dragging: false))
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        #expect(keys == 1)
        r.end(sessionID: try #require(r.currentSessionID))
        r.configure(trigger: nil, eligible: false)
        #expect(r.handle(.keyDown, event: event(.keyDown, key: 124, repeatDown: true), dragging: false))
        #expect(r.handle(.keyUp, event: event(.keyUp, key: 124), dragging: false))
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        #expect(keys == 1 && !r.needsTap)
    }
    @Test func dedicatedFavoritesPersistSwapStayIndependentAndReset() {
        Preferences.resetAll()
        let initial = Preferences.quickControlFavorites
        #expect(initial == ["glove", "lavender", "coral", "plush", "robot", "laser"])
        #expect(Preferences.storage.stringArray(forKey: RadialFavorites.storageKey) == initial)
        Preferences.pinnedStyles = [.laser]
        #expect(Preferences.quickControlFavorites == initial)
        #expect(Preferences.assignQuickControlFavorite("lavender", to: 0))
        #expect(Preferences.quickControlFavorites == ["lavender", "glove", "coral", "plush", "robot", "laser"])
        #expect(Preferences.assignQuickControlFavorite("custom-absent", to: 5))
        #expect(Preferences.quickControlFavorites[5] == "custom-absent")
        Preferences.disabledPointerIDs = ["glove"]
        #expect(Preferences.quickControlFavorites[1] == "glove")
        #expect(!Preferences.assignQuickControlFavorite("../bad", to: 0))
        #expect(!Preferences.assignQuickControlFavorite("laser", to: 6))
        Preferences.resetAll()
        #expect(Preferences.quickControlFavorites == initial)
    }
}

@Suite(.serialized) @MainActor struct RadialAccessibilityInputTests {
    @Test(arguments: [RadialMode.held, .persistent])
    func voiceOverChordsIncludingEscapeAlwaysPass(mode: RadialMode) throws {
        let input = RadialInput(nativeKeyState: { _ in false }, scheduleHold: { _, _ in })
        input.configure(trigger: .option, eligible: true)
        func event(_ type: CGEventType, key: Int64) -> CGEvent {
            let event = CGEvent(source: nil)!
            event.type = type; event.flags = [.maskControl, .maskAlternate]; event.setIntegerValueField(.keyboardEventKeycode, value: key)
            return event
        }
        if mode == .persistent { #expect(input.openPersistent(at: .zero) != nil) }
        else {
            let flags = CGEvent(source: nil)!; flags.type = .flagsChanged; flags.flags = .maskAlternate
            _ = input.handle(.flagsChanged, event: flags, dragging: false)
            input.advanceHold(flags: .maskAlternate, dragging: false, now: .greatestFiniteMagnitude)
        }
        for code: Int64 in [53, 124, 36, 49] {
            #expect(!input.handle(.keyDown, event: event(.keyDown, key: code), dragging: false))
            #expect(!input.handle(.keyUp, event: event(.keyUp, key: code), dragging: false))
            #expect(input.diagnostics["open"] as? Bool == true)
        }
    }
    @Test func listWheelPassesToNativeScrollViewWithoutGivingUpPointerPairs() throws {
        let input = RadialInput(nativeKeyState: { _ in false }, scheduleHold: { _, _ in })
        input.configure(trigger: nil, eligible: true)
        let id = try #require(input.openPersistent(at: .zero))
        let event = CGEvent(source: nil)!
        #expect(input.handle(.scrollWheel, event: event, dragging: false))
        input.setListMode(true)
        #expect(!input.handle(.scrollWheel, event: event, dragging: false))
        #expect(input.handle(.leftMouseDown, event: event, dragging: false))
        input.end(sessionID: id)
        #expect(input.handle(.leftMouseUp, event: event, dragging: false))
    }
}
