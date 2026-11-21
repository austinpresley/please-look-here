import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

final class SettingsModel: ObservableObject {
    @Published var section: SettingsSection = .pointers {
        didSet {
            if section == .appearance || section == .sound {
                pointerInspector.scope = .defaults
                revealDefaultSound = section == .sound
                section = .pointers
            }
            if section == .about { section = .general }
            if section != oldValue {
                cancelShortcutNavigation()
                if section == .shortcuts { resetShortcutSections() }
            }
        }
    }
    let presetsModel = PresetsSettingsModel()
    @Published var showingAbout = false
    @Published var drawingAdvanced = false
    @Published var scrollToBottom = false
    @Published var toolsPane: ToolSettingsPane = .drawing
    @Published var revealDefaultSound = false
    @Published var pointerInspector = PointerInspectorState()
    @Published var libraryFilter = PointerLibraryFilter()
    func inspectPointer(_ style: PointerStyle) {
        pointerInspector.select(style)
        if PointerCatalog.entries.first(where: { $0.style == style })?.selectable == true { selectPointer(style) }
    }
    @Published var shortcutQuery = ""
    @Published var shortcutAssignedOnly = false
    @Published var shortcutDisclosure = ShortcutDisclosureState()

    func resetShortcutSections() {
        shortcutDisclosure.reset()
        shortcutQuery = ""
        shortcutAssignedOnly = false
    }

    func navigate(_ route: SettingsRoute) {
        section = route.section
        if let tool = route.tool { toolsPane = tool }
        if route.defaults { pointerInspector.scope = .defaults }
        if route.sound { revealDefaultSound = true }
    }
    @Published var pinMessage: String?
    @Published var pointerMessage: String?
    @Published var pointerErrorID: String?
    @Published private var revision = 0

    var applyToggleShortcut: ((Shortcut?) -> Bool)?
    var applyClearShortcut: ((Shortcut?) -> Bool)?
    var applyPresentationShortcut: ((PresentationAction, Shortcut?) -> Bool)?
    var applyMode: ((PointerMode) -> Bool)?
    @Published var generalMessage: String?
    var onContentHeightChanged: ((CGFloat) -> Void)?
    var onRecording: ((Bool) -> Void)?
    var updater: Updater?
    @Published var suggestedResult: SuggestedShortcuts.Result?
    var suggestedUndo: SuggestedShortcuts.Undo?
    @Published var shortcutError: String?
    @Published var shortcutConflicts: [String: String] = [:]
    @Published private(set) var shortcutFocusRequest: ShortcutFocusRequest?
    var editQuickControlFavorites: (() -> Void)?
    var openPractice: ((PracticeLesson) -> Void)?
    var onShortcutNavigationLayout: (() -> Void)?

    func cancelShortcutNavigation() { shortcutFocusRequest = nil }

    func focusShortcut(_ target: PracticeShortcutTarget) {
        section = .shortcuts
        shortcutQuery = ""
        shortcutAssignedOnly = false
        shortcutDisclosure.reveal(command: target.rawValue)
        shortcutFocusRequest = ShortcutFocusRequest(target: target)
    }

    func focusShortcut(command: String) {
        section = .shortcuts
        shortcutQuery = ""
        shortcutAssignedOnly = false
        shortcutDisclosure.reveal(command: command)
        shortcutFocusRequest = ShortcutFocusRequest(target: PracticeShortcutTarget(rawValue: command) ?? .pointer, command: command)
    }

    func shortcutExpansion(_ group: ShortcutSettingsGroup) -> Binding<Bool> {
        Binding(get: { self.shortcutDisclosure.expanded.contains(group) },
                set: { self.shortcutDisclosure.set(group, expanded: $0) })
    }

    private var observer: Any?
    private var handsObserver: Any?
    @Published var artworkRecovery: PointerArtworkRecovery?
    @Published var handMessage: String?
    @Published var gestureMessage: String?
    @Published private(set) var removedHands: [HandRecoveryStore.Receipt] = []

    private func refreshRemovedHands() {
        guard FileManager.default.fileExists(atPath: CustomHands.directory.appendingPathComponent("hands.json").path) else { return }
        do { removedHands = try HandRecoveryStore(directory: CustomHands.directory).pendingRemovals() }
        catch { handMessage = error.localizedDescription }
    }

    init() {
        observer = NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [weak self] _ in
            self?.previewSound?.updateOutput(Preferences.soundOutput)
            self?.revision += 1
        }
        handsObserver = NotificationCenter.default.addObserver(forName: CustomHands.changed, object: nil, queue: .main) { [weak self] _ in
            self?.revision += 1
        }
        CustomHands.reload()
        HandAsset.preloadThumbnails(PointerStyle.allCases.compactMap(\.assetName)) { [weak self] in
            self?.revision += 1
        }
        refreshRemovedHands()
        if let message = CustomHands.recoveryMessage { handMessage = message }
    }

    struct HandDraft {
        let image: CGImage
        let ink: UInt32
    }

    @Published var makingHand = false
    @Published var handIdea = ""
    @Published var handName = ""
    @Published var draft: HandDraft?
    @Published var draftError: String?
    @Published var promptCopied = false

    func startMakingHand() {
        draft = nil
        draftError = nil
        promptCopied = false
        handMessage = nil
        makingHand = true
    }

    private var copiedReset: DispatchWorkItem?

    func copyPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(HandMaker.prompt(for: handIdea), forType: .string)
        promptCopied = true
        copiedReset?.cancel()
        let reset = DispatchWorkItem { [weak self] in self?.promptCopied = false }
        copiedReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: reset)
    }

    func openChatGPT() {
        copyPrompt()
        if let url = URL(string: "https://chatgpt.com/") {
            NSWorkspace.shared.open(url)
        }
    }
    func chooseGestureFile(_ slot: HandGestureSlot, for style: PointerStyle) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .webP, .image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose one upright hand in the pose you want, with a flat wrist and transparent background. Do not include a stick, shadow or checkerboard."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try HandGestureCatalog.add(from: url, slot: slot, style: style); gestureMessage = "\(slot.title) artwork saved for \(style.title)." }
        catch let problem as HandMaker.Problem { gestureMessage = problem.message }
        catch { gestureMessage = "The artwork could not be saved. Try another image." }
        refresh()
    }
    func restoreGesture(_ slot: HandGestureSlot, for style: PointerStyle) {
        do { try HandGestureCatalog.restore(slot, style: style); gestureMessage = "\(slot.stockTitle) restored for \(style.title)." }
        catch { gestureMessage = "The starter artwork could not be restored. Try again." }
        refresh()
    }

    func chooseHandFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .webP, .image]
        panel.allowsMultipleSelection = false
        panel.message = "Pick the PNG of your hand"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        loadDraft(url)
    }

    func loadDraft(_ url: URL) {
        do {
            let made = try HandMaker.make(from: url)
            draft = HandDraft(image: made.image, ink: made.ink)
            draftError = nil
            if handName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                handName = CustomHands.suggestedName(for: url)
            }
        } catch let problem as HandMaker.Problem {
            draft = nil
            draftError = problem.message
        } catch {
            draft = nil
            draftError = "Look Here Please couldn't read that file."
        }
    }

    func saveDraft() {
        guard let draft = draft else {
            return
        }
        do {
            let style = try CustomHands.add(draft.image, ink: draft.ink, name: handName)
            if let name = style.assetName {
                _ = HandAsset.thumbnail(name)
            }
            var pinned = Preferences.pinnedStyles
            if pinned.count < Preferences.maxPinned {
                pinned.insert(style, at: max(0, pinned.count - (pinned.last == .laser ? 1 : 0)))
                Preferences.pinnedStyles = pinned
                handMessage = "\(style.title) is in your toolbar."
            } else {
                handMessage = "\(style.title) is ready. Unstar a favorite, then star this hand."
            }
            PointerStyle.saved = style
            pointerInspector.select(style)
            libraryFilter = PointerLibraryFilter()
            NotificationCenter.default.post(name: Preferences.changed, object: nil)
            self.draft = nil
            handIdea = ""
            makingHand = false
        } catch {
            draftError = error.localizedDescription
        }
    }

    func removeHand(_ style: PointerStyle) {
        let name = style.title
        do {
            let configurations = try PointerConfigurationDocument.load(from: Preferences.storage)
            let snapshot = try PointerRemovalConfiguration.snapshot(for: style.rawValue, in: configurations)
            _ = try CustomHands.remove(style, extensions: [PointerRemovalConfiguration.receiptKey: snapshot])
            // Retain saved overrides while the ID is absent. The receipt still
            // restores the original value if a later import edits that ID.
            Preferences.performBatch {
                let pinned = Preferences.pinnedStyles.filter { $0 != style }
                Preferences.pinnedStyles = pinned.isEmpty ? PointerStyle.defaultPinned : pinned
                PointerCatalog.reconcile()
            }
            handMessage = "\(name) was removed. Undo restores its artwork and settings."
            refreshRemovedHands()
        } catch { handMessage = error.localizedDescription }
        revision += 1
    }

    func undoHandRemoval() {
        guard let receipt = removedHands.first else { return }
        do {
            let warning = try CustomHands.restore(receipt)
            PointerCatalog.reconcile()
            handMessage = warning ?? "\(receipt.hand.name) was restored."
            refreshRemovedHands()
        } catch { handMessage = error.localizedDescription }
        revision += 1
    }

    func refresh() {
        revision += 1
    }

    func setPointerEnabled(_ enabled: Bool, for style: PointerStyle) {
        do {
            try PointerCatalog.setEnabled(enabled, for: style)
            pointerMessage = nil
            pointerErrorID = nil
        } catch let problem as PointerCatalog.Problem {
            pointerMessage = problem.message
            pointerErrorID = style.rawValue
        } catch { pointerMessage = "Unable to change this pointer." }
        revision += 1
    }

    func selectPointer(_ style: PointerStyle) {
        do {
            try PointerCatalog.validateSelection(style)
            Preferences.performBatch { PointerStyle.saved = style }
            pointerMessage = nil
            pointerErrorID = nil
        } catch let problem as PointerCatalog.Problem {
            pointerMessage = problem.message
            pointerErrorID = style.rawValue
        } catch { pointerMessage = "Unable to select this pointer." }
    }

    func chooseCaptureFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = Preferences.captureFolder
        panel.message = "Choose a folder for screenshots"
        if panel.runModal() == .OK, let url = panel.url { Preferences.captureFolder = url }
    }

    func binding<T>(_ get: @escaping () -> T, _ set: @escaping (T) -> Void) -> Binding<T> {
        Binding(get: get, set: { value in
            set(value)
            self.revision += 1
        })
    }

    private var previewSound: SoundAudition?

    func preview(_ choice: TapSoundChoice) {
        if previewSound == nil {
            previewSound = SoundAudition()
        }
        previewSound?.preview(choice, output: Preferences.soundOutput)
    }
    func stopPreview() { previewSound?.stop() }

    func resetToolbar() {
        pinMessage = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            Preferences.pinnedStyles = PointerStyle.defaultPinned
        }
    }

    func resetAll(exportBackup: (() -> Void)? = nil) {
        let alert = NSAlert()
        alert.messageText = "Reset all settings?"
        alert.informativeText = "All pointers are enabled and shortcut assignments are cleared. Toolbar pointers, size, shadow, drawing and sound return to their initial settings. Custom hands, Open at login and Accessibility stay as they are."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if exportBackup != nil { alert.addButton(withTitle: "Export Backup First…") }
        let response = alert.runModal()
        if response == .alertThirdButtonReturn { exportBackup?(); return }
        guard response == .alertFirstButtonReturn else {
            return
        }
        Preferences.resetAll()
        shortcutError = nil
        pinMessage = nil
        pointerMessage = nil
        pointerErrorID = nil
        revision += 1
    }

    func pin(_ style: PointerStyle) {
        var pinned = Preferences.pinnedStyles
        if pinned.contains(style) {
            unpin(style)
            return
        }
        if pinned.count >= Preferences.maxPinned {
            pinMessage = "The toolbar is full. Remove one above to add \(style.title)."
            return
        }
        pinned.append(style)
        pinMessage = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            Preferences.pinnedStyles = pinned
        }
    }

    func unpin(_ style: PointerStyle) {
        var pinned = Preferences.pinnedStyles
        guard let i = pinned.firstIndex(of: style) else {
            return
        }
        if pinned.count == 1 {
            pinMessage = "Keep at least one pointer in the toolbar."
            return
        }
        pinned.remove(at: i)
        pinMessage = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            Preferences.pinnedStyles = pinned
        }
    }

}
