import AppKit
import Carbon.HIToolbox
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct UsabilityFix1Tests {
    @Test func suggestedUndoPreservesUnrelatedAndLaterEditedAssignments() throws {
        Preferences.resetAll(); defer { Preferences.resetAll() }
        let (_, undo) = SuggestedShortcuts.apply(check: { $0.id == "capture" ? "Reserved" : nil }) { item in
            switch item.assignment {
            case .hold(let trigger): Preferences.radialTrigger = trigger
            case .key(let key):
                if item.id == "toggle" { Preferences.toggleShortcut = key }
                else { Preferences.setShortcut(key, for: .undo) }
            }
            return nil
        }
        let pen = Shortcut(keyCode: 11, modifiers: UInt32(cmdKey), display: "⌘B")
        Preferences.setShortcut(pen, for: .pen)
        Preferences.radialTrigger = .shift
        let edited = undo.restore()
        #expect(edited == ["Quick controls"])
        #expect(Preferences.shortcut(for: .pen) == pen)
        #expect(Preferences.radialTrigger == .shift)
        #expect(Preferences.toggleShortcut == nil && Preferences.shortcut(for: .undo) == nil)
    }
    @Test func skippedSuggestionBecomesEligibleAfterConflictClears() throws {
        Preferences.resetAll(); defer { Preferences.resetAll() }
        let model = SettingsModel()
        let toggle = SuggestedShortcuts.items[0]
        guard case .key(let key) = toggle.assignment else { return }
        Preferences.clearShortcut = key
        let (result, _) = SuggestedShortcuts.apply(check: { SuggestedShortcuts.conflict($0, probe: { _ in true }) }, assign: { _ in "Test skip" })
        model.suggestedResult = result
        Preferences.clearShortcut = nil
        #expect(model.suggestedRows.first?.status == .willAdd)
    }
    @Test func replacedBuiltInBaseArtworkRoundTripsAndRecoversActualBytes() async throws {
        let source = try PresentationArchiveTests.Fixture(); defer { source.finish() }
        let target = try PresentationArchiveTests.Fixture(); defer { target.finish() }
        let replacement = try source.png(red: 0.35)
        try source.write(replacement, "hand_lavender.png")
        let exported = try PortablePresentationArchive.decode(source.store.captureArchive().encoded())
        #expect(exported.artwork["hand_lavender.png"] == replacement)
        let plan = try target.store.preview(exported)
        let receipt = try await Task.detached { try target.store.apply(plan) }.value
        #expect(try target.read("hand_lavender.png") == replacement)
        let conflicting = try PresentationArchiveTests.Fixture(); defer { conflicting.finish() }
        try conflicting.write(try conflicting.png(red: 0.8), "hand_lavender.png")
        #expect(try !conflicting.store.preview(exported).preview.canApply)
        try target.store.restore(receipt)
        #expect(!FileManager.default.fileExists(atPath: target.directory.appendingPathComponent("hand_lavender.png").path))
    }
    @Test func brokenHistoricalRecoveryDoesNotHideNewerUndo() throws {
        let f = try PresentationArchiveTests.Fixture(); defer { f.finish() }
        let old = UUID()
        try f.write(Data("{broken".utf8), ".Presentation/Recovery/\(old).json")
        let latest = try f.store.savePreset(name: "Valid")
        #expect(try f.store.latestRecovery()?.id == latest.id)
    }
    @Test(arguments: [false, true]) func toolbarKeepsLeaseAcrossBothPickerRowsAfterDeadlineAndDismissesExplicitly(_ allowed: Bool) throws {
        _ = NSApplication.shared
        let toolbar = Toolbar()
        defer { toolbar.hide() }
        _ = toolbar.verify(["open": true, "selection": "pen", "permission": allowed])
        let outside = CGPoint(x: toolbar.frame.minX, y: toolbar.frame.maxY + 200)
        #expect(!toolbar.wantsReveal(mouse: outside, deadline: .distantPast))
        toolbar.showPicker()
        let child = try #require(toolbar.windows.first { $0.isVisible && $0.frame != toolbar.frame })
        func buttons(_ view: NSView) -> [NSButton] { (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons) }
        let choices = buttons(try #require(child.contentView))
        for title in ["Pen", "Text"] {
            let button = try #require(choices.first { $0.accessibilityLabel() == title })
            let rect = child.convertToScreen(button.convert(button.bounds, to: nil))
            #expect(toolbar.wantsReveal(mouse: CGPoint(x: rect.midX, y: rect.midY), deadline: .distantPast))
        }
        #expect(toolbar.wantsReveal(mouse: outside, deadline: .distantPast))
        toolbar.setRevealed(false)
        #expect(!child.isVisible && !toolbar.revealed)
        #expect(!toolbar.wantsReveal(mouse: outside, deadline: .distantPast))
    }
    @Test func nonHandEditingAndEachResetPreserveIndependentOverrides() throws {
        Preferences.resetAll(); defer { Preferences.resetAll() }
        let model = SettingsModel()
        for style in [PointerStyle.laser, .spotlight, .presentation] {
            model.editPointer(style) { $0.soundEnabled = false; $0.sound = .thock; if style == .presentation { $0.shadow = false } }
            model.resetPointer(style, field: .soundEnabled)
            var value = try #require(PointerConfigurationDocument.load(from: Preferences.storage).pointers[style.rawValue])
            #expect(value.soundEnabled == nil && value.sound == .thock)
            #expect(value.shadow == (style == .presentation ? false : nil))
            model.editPointer(style) { $0.soundEnabled = true }
            model.resetPointer(style, field: .sound)
            value = try #require(PointerConfigurationDocument.load(from: Preferences.storage).pointers[style.rawValue])
            #expect(value.sound == nil && value.soundEnabled == true)
            if style == .presentation {
                model.resetPointer(style, field: .shadow)
                value = try #require(PointerConfigurationDocument.load(from: Preferences.storage).pointers[style.rawValue])
                #expect(value.shadow == nil && value.soundEnabled == true)
            }
        }
    }
    @Test func recoveryCatalogueRetainsUnreadableEntriesWithoutLoadingPayloads() throws {
        let f = try PresentationArchiveTests.Fixture(); defer { f.finish() }
        let broken = UUID()
        try f.write(Data("{broken".utf8), ".Presentation/Recovery/\(broken).json")
        let valid = try f.store.savePreset(name: "New valid copy")
        var store = f.store
        var payloadReads = 0
        store.loadRecoveryPayload = { url in payloadReads += 1; return try Data(contentsOf: url) }
        let entries = try store.recoveryCatalogue()
        #expect(payloadReads == 0 && entries.count == 2)
        #expect(entries.first?.id == valid.id)
        #expect(entries.first { $0.id == broken }?.problem != nil)
        #expect(try store.latestRecovery()?.id == valid.id)
        #expect(payloadReads == 1)
        try store.restore(try #require(try store.latestRecovery()))
        #expect(try store.presets().isEmpty)
    }
    @Test func permissionPrimaryButtonAccessibleNameTracksEveryNativeTitle() {
        _ = NSApplication.shared
        let welcome = WelcomeWindow()
        defer { welcome.nativeWindow?.orderOut(nil) }
        for (drawing, allowed, title) in [(false, false, "Show Pointer"), (true, false, "Open Settings"), (true, true, "Start Drawing")] {
            welcome.accessibility = { allowed }
            welcome.show(forDrawing: drawing)
            #expect(welcome.primaryButton.title == title)
            #expect(welcome.primaryButton.accessibilityLabel() == title)
        }
    }
    @Test func tapStopIsSynchronousIdempotentAndReleasesNativeContext() {
        _ = NSApplication.shared
        var installed = 0
        for _ in 0..<24 {
            weak var released: InputTap?
            autoreleasepool {
                let tap = InputTap()
                released = tap
                if tap.install() { installed += 1 }
                tap.stop(); tap.stop()
                #expect(!tap.isInstalled)
                #expect(tap.diagnostics["enabled"] as? Bool == false)
            }
            #expect(released == nil)
        }
        if AXIsProcessTrusted() { #expect(installed == 24) }
        print("InputTap native lifecycle: \(installed)/24 installed, stopped twice and released")
    }
    @Test func injectedTapCanRestartAfterStopWithoutKeepingQueuedNotifications() throws {
        var enabled = false
        let tap = InputTap(installation: .init(install: { true }, isEnabled: { enabled }, setEnabled: { enabled = $0 }))
        for _ in 0..<8 {
            #expect(tap.install())
            tap.setActive(true); #expect(enabled)
            tap.stop(); tap.stop()
            #expect(!enabled && !tap.isInstalled)
        }
    }
    @Test func practiceAnnouncesCurrentStepAndTracksOnlyCompletedExercises() {
        let session = GettingStartedPracticeSession(pointerConfiguration: .current)
        #expect(session.completedSteps.isEmpty)
        session.pointerOn = true; session.clickPracticeButton()
        session.select(.drawing)
        #expect(session.progressAnnouncement == "Step 2 of 4, Drawing")
        #expect(session.completedSteps == [.pointer] && !session.succeeded)
        session.drawing.begin(at: .zero); session.drawing.extend(to: CGPoint(x: 70, y: 70)); session.drawing.end()
        #expect(session.completedSteps == [.pointer, .drawing])
        session.replayAll()
        #expect(session.completedSteps.isEmpty && !session.succeeded)
    }
    @Test func heldAssignmentTeachesHoldAndUsesFullAccessibleInstruction() {
        let assignment = SuggestedShortcuts.Assignment.hold(.option)
        #expect(assignment.display == "⌥")
        #expect(assignment.accessibilityLabel == "Hold Option to open Quick controls")
        #expect(RadialTrigger.option.holdInstruction == "Hold ⌥")
    }

    @Test func shortcutGestureArtworkKeepsRealOKAndShakaForNonHands() throws {
        let first = try #require(ShortcutGestureArtwork.image(.first, style: .laser))
        let second = try #require(ShortcutGestureArtwork.image(.second, style: .laser))
        #expect(first.tiffRepresentation != second.tiffRepresentation)
    }
    @Test func recoveryReviewNamesRemovedAndReturningPresets() throws {
        let f = try PresentationArchiveTests.Fixture(); defer { f.finish() }
        _ = try f.store.savePreset(name: "Workshop")
        let saved = try #require(try f.store.presets().first)
        let removal = try f.store.removePreset(saved.id)
        _ = try f.store.savePreset(name: "Quiet demo")
        let plan = try f.store.previewRestore(removal)
        #expect(plan.presetChanges.contains("Restore 1: Workshop"))
        #expect(plan.presetChanges.contains("Remove 1: Quiet demo"))
    }

}
