import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct RadialTests {
    private func input(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                       nativeKeyState: @escaping (CGKeyCode) -> Bool = { _ in false }) -> RadialInput {
        RadialInput(clock: clock, nativeKeyState: nativeKeyState)
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
    @Test func accessibleNavigationUsesSameCatalogAndCommands() {
        var s = session()
        #expect(s.activate(0) == nil && s.group == "pointer")
        #expect(s.activate(7) == nil && s.page == 1)
        #expect(s.activate(0)?["style"] as? String == "p6")
        s.back(); #expect(s.group == nil && s.candidate == nil)
    }
    @Test func fixedDirectionsAndEdgeFitWithoutCursorWarp() {
        let bounds = CGRect(x: -1200, y: 24, width: 1200, height: 800)
        for cursor in [CGPoint(x: -1198, y: 26), CGPoint(x: -2, y: 820), CGPoint(x: -600, y: 424)] {
            let g = RadialGeometry(cursor: cursor, bounds: bounds)
            #expect(bounds.contains(g.frame))
            for slot in 0..<8 {
                let p = RadialGeometry.point(slot: slot, radius: 216, center: g.center)
                #expect(RadialGeometry.direction(p, from: g.center) == slot)
                #expect(g.frame.contains(p))
            }
        }
    }
    private func session(shifted: Bool = false) -> RadialSession {
        let g = RadialGeometry(cursor: shifted ? .zero : CGPoint(x: 500, y: 500), bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let root = [RadialItem(id: "pointer", title: "Pointer", symbol: "", group: "pointer")]
        let all = (0..<37).map { RadialItem(id: "p\($0)", title: "Pointer \($0)", symbol: "", request: ["style": "p\($0)"]) }
        return RadialSession(geometry: g, root: root, groups: ["pointer": all])
    }
    @Test func hierarchyBacktrackingImmediateReleaseAndShiftedArming() {
        var s = session(shifted: true)
        #expect(!s.armed && s.candidate == nil)
        s.move(RadialGeometry.point(slot: 0, radius: 128, center: s.geometry.center))
        #expect(s.group == nil && s.candidate == nil)
        s.move(s.geometry.center); #expect(s.armed)
        s.move(RadialGeometry.point(slot: 0, radius: 128, center: s.geometry.center)); #expect(s.group == "pointer")
        #expect(s.candidate == nil)
        s.move(RadialGeometry.point(slot: 1, radius: 216, center: s.geometry.center)); #expect(s.candidate?.id == "p1")
        s.move(s.geometry.center); #expect(s.group == nil && s.candidate == nil)
        s.move(CGPoint(x: s.geometry.center.x + 400, y: s.geometry.center.y)); #expect(s.candidate == nil)
    }
    @Test func completeCatalogPagesKeepTargetsAndRequireFreshMovement() {
        var s = session(); let center = s.geometry.center
        s.move(RadialGeometry.point(slot: 0, radius: 128, center: center))
        var ids: [String] = []
        for page in 0..<7 {
            #expect(s.page == page && s.pages == 7)
            ids += s.items.filter { $0.request != nil }.map(\.id)
            if page < 6 {
                s.move(RadialGeometry.point(slot: 7, radius: 216, center: center))
                #expect(s.page == page + 1 && !s.pageArmed && s.candidate == nil)
                s.move(RadialGeometry.point(slot: 7, radius: 216, center: center))
                #expect(s.page == page + 1)
                s.move(RadialGeometry.point(slot: 0, radius: 144, center: center))
            }
        }
        #expect(ids == (0..<37).map { "p\($0)" })
        #expect(!s.items[7].enabled)
    }
}
