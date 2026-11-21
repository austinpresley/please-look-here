import AppKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct SettingsRedesignTests {
    @Test func allShortcutSectionsStartClosedEvenWithSavedAssignments() {
        let old = Preferences.toggleShortcut
        defer { Preferences.toggleShortcut = old }
        Preferences.toggleShortcut = Shortcut(keyCode: 35, modifiers: 2048, display: "⌥P")
        let model = SettingsModel()
        model.section = .shortcuts
        #expect(model.shortcutDisclosure.expanded.isEmpty)
        #expect(ShortcutSettingsGroup.allCases.count == 7)
        model.shortcutDisclosure.set(.pointer, expanded: true)
        model.section = .general
        model.section = .shortcuts
        #expect(model.shortcutDisclosure.expanded.isEmpty)
        #expect(Preferences.toggleShortcut != nil)
    }

    @Test func explicitLinksOpenOnlyTheRequiredSection() {
        for target in PracticeShortcutTarget.allCases {
            let model = SettingsModel()
            model.focusShortcut(target)
            #expect(model.shortcutDisclosure.expanded == [.containing(target.rawValue)])
            #expect(model.shortcutFocusRequest?.controlIdentifier == target.controlIdentifier)
        }
        let model = SettingsModel()
        model.focusShortcut(command: PresentationAction.captureRegion.rawValue)
        #expect(model.shortcutDisclosure.expanded == [.presenting])
        #expect(model.shortcutFocusRequest?.controlIdentifier == "settings.shortcut.capture-region")
        model.resetShortcutSections()
        #expect(model.shortcutDisclosure.expanded.isEmpty)
    }

    @Test func oldAndNewSectionRoutesRemainCompatible() {
        #expect(SettingsSection.sidebarCases.count == 5)
        #expect(!SettingsSection.sidebarCases.contains(.sound))
        for section in SettingsSection.allCases { #expect(SettingsRoute.parse(section.rawValue) != nil) }
        let model = SettingsModel()
        model.navigate(SettingsRoute.parse("sound")!)
        #expect(model.section == .pointers && model.revealDefaultSound && model.pointerInspector.isDefaults)
        model.navigate(SettingsRoute.parse("screenshots")!)
        #expect(model.section == .drawing && model.toolsPane == .screenshots)
        model.navigate(SettingsRoute.parse("magnification")!)
        #expect(model.section == .drawing && model.toolsPane == .magnification)
        #expect(SettingsRoute.parse("not-a-settings-page") == nil)
        #expect(SettingsRoute.parse("drawing")?.tool == .drawing)
    }

    @Test func destinationTransitionsNeverLoseAllOutputsOrChangeTheFolder() {
        let saves = Preferences.captureSaves, copies = Preferences.captureCopies, folder = Preferences.captureFolder
        defer {
            ScreenshotDestination(saves: saves, copies: copies).apply()
            Preferences.captureFolder = folder
        }
        for before in ScreenshotDestination.allCases {
            for after in ScreenshotDestination.allCases {
                before.apply(); after.apply()
                #expect(Preferences.captureSaves == after.saves)
                #expect(Preferences.captureCopies == after.copies)
                #expect(Preferences.captureSaves || Preferences.captureCopies)
                #expect(Preferences.captureFolder == folder)
            }
        }
    }

    @Test func nativeCollapsedSectionsDoNotMountRecorderControlsUntilExplicitlyOpened() throws {
        _ = NSApplication.shared
        let model = SettingsModel()
        model.section = .shortcuts
        let host = SettingsHostingView(model: model)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 784, height: 640), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        #expect(ShortcutNavigation.control(for: .pointer, in: host) == nil)
        #expect(ShortcutNavigation.control(for: .drawing, in: host) == nil)
        model.focusShortcut(.drawing)
        host.layoutSubtreeIfNeeded()
        let pen = try #require(ShortcutNavigation.control(for: .drawing, in: host))
        #expect(!pen.isHiddenOrHasHiddenAncestor)
        #expect(ShortcutNavigation.control(for: .pointer, in: host) == nil)
        #expect((pen as? ShortcutRecorder)?.isRecording == false)
        #expect(!window.isVisible)
    }

    @Test func loadingAHandImageKeepsTheNameAlreadyTyped() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let width = 128, height = 224
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 20..<200 {
            for x in 20..<100 {
                let finger = y < 100 && (36..<52).contains(x)
                let palm = (80..<180).contains(y)
                let wrist = y >= 180 && (40..<80).contains(x)
                if finger || palm || wrist {
                    let i = (y * width + x) * 4
                    pixels[i] = 150; pixels[i + 1] = 80; pixels[i + 2] = 220; pixels[i + 3] = 255
                }
            }
        }
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let input = folder.appendingPathComponent("valid-hand.png")
        try HandMaker.write(image, to: input)
        let model = SettingsModel()
        model.handName = "My hand"
        model.loadDraft(input)
        _ = try #require(model.draft)
        #expect(model.handName == "My hand")
    }

    @Test func collapsingASectionStopsItsActiveRecorder() async throws {
        _ = NSApplication.shared
        let model = SettingsModel()
        model.section = .shortcuts
        model.shortcutDisclosure.set(.pointer, expanded: true)
        var events: [Bool] = []
        model.onRecording = { events.append($0) }
        let host = SettingsHostingView(model: model)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 784, height: 640), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let recorder = try #require(ShortcutNavigation.control(for: .pointer, in: host) as? ShortcutRecorder)
        recorder.performClick(nil)
        #expect(recorder.isRecording)
        model.shortcutDisclosure.set(.pointer, expanded: false)
        host.layoutSubtreeIfNeeded()
        #expect(!recorder.isRecording)
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        #expect(events == [true, false])
        #expect(!window.isVisible)
    }
}
