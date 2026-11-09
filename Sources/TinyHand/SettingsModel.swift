import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

final class SettingsModel: ObservableObject {
    @Published var section: SettingsSection = .general
    @Published var pinMessage: String?
    @Published private var revision = 0

    var applyToggleShortcut: ((Shortcut) -> Bool)?
    var applyClearShortcut: ((Shortcut) -> Bool)?
    var applyPresentationShortcut: ((PresentationAction, Shortcut) -> Bool)?
    var applyMode: ((PointerMode) -> Bool)?
    @Published var generalMessage: String?
    var onContentHeightChanged: ((CGFloat) -> Void)?
    var onRecording: ((Bool) -> Void)?
    var updater: Updater?
    @Published var shortcutError: String?

    private var observer: Any?
    private var handsObserver: Any?
    @Published var handMessage: String?

    init() {
        observer = NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [weak self] _ in
            self?.revision += 1
        }
        handsObserver = NotificationCenter.default.addObserver(forName: CustomHands.changed, object: nil, queue: .main) { [weak self] _ in
            self?.revision += 1
        }
        HandAsset.preloadThumbnails(PointerStyle.allCases.compactMap(\.assetName)) { [weak self] in
            self?.revision += 1
        }
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
        var parts = URLComponents(string: "https://chatgpt.com/")
        parts?.queryItems = [URLQueryItem(name: "q", value: HandMaker.prompt(for: handIdea))]
        if let url = parts?.url {
            NSWorkspace.shared.open(url)
        }
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
            handName = CustomHands.suggestedName(for: url)
        } catch let problem as HandMaker.Problem {
            draft = nil
            draftError = problem.message
        } catch {
            draft = nil
            draftError = "TinyHand couldn't read that file."
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
                handMessage = "\(style.title) is ready. Click it to add it to the toolbar."
            }
            PointerStyle.saved = style
            NotificationCenter.default.post(name: Preferences.changed, object: nil)
            self.draft = nil
            handIdea = ""
            makingHand = false
        } catch {
            draftError = "TinyHand couldn't save that hand."
        }
    }

    func removeHand(_ style: PointerStyle) {
        let pinned = Preferences.pinnedStyles.filter { $0 != style }
        Preferences.pinnedStyles = pinned.isEmpty ? PointerStyle.defaultPinned : pinned
        if PointerStyle.saved == style {
            PointerStyle.saved = .lavender
        }
        CustomHands.remove(style)
        handMessage = nil
        NotificationCenter.default.post(name: Preferences.changed, object: nil)
        revision += 1
    }

    func refresh() {
        revision += 1
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

    private var previewSound: TapSound?

    func warmPreview() {
        if previewSound == nil {
            previewSound = TapSound()
        }
        previewSound?.warm()
    }

    func preview(_ choice: TapSoundChoice) {
        if previewSound == nil {
            previewSound = TapSound(choice)
        }
        previewSound?.load(choice)
        previewSound?.play()
    }

    @Published var dragging: PointerStyle?
    @Published private var draftOrder: [PointerStyle]?

    var pinnedOrder: [PointerStyle] {
        draftOrder ?? Preferences.pinnedStyles
    }

    private(set) var baseOrder: [PointerStyle] = []

    func beginDrag(_ style: PointerStyle) {
        dragging = style
        baseOrder = Preferences.pinnedStyles
        draftOrder = baseOrder
        pinMessage = nil
    }

    func setDraft(_ order: [PointerStyle]) {
        guard order != draftOrder else {
            return
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            draftOrder = order
        }
    }

    func cancelDrag() {
        draftOrder = nil
        dragging = nil
    }

    func resetToolbar() {
        pinMessage = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            Preferences.pinnedStyles = PointerStyle.defaultPinned
        }
    }

    func resetAll() {
        let alert = NSAlert()
        alert.messageText = "Reset all settings?"
        alert.informativeText = "Shortcuts, toolbar pointers, size, shadow, drawing and sound go back to how they were at first. Open at login and Accessibility stay as they are."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }
        Preferences.resetAll()
        _ = applyToggleShortcut?(.toggleDefault)
        _ = applyClearShortcut?(.clearDefault)
        shortcutError = nil
        pinMessage = nil
        revision += 1
    }

    func endDrag() {
        if let order = draftOrder {
            Preferences.pinnedStyles = order
        }
        draftOrder = nil
        dragging = nil
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

    func swap(_ old: PointerStyle, for new: PointerStyle) {
        var pinned = Preferences.pinnedStyles
        guard let i = pinned.firstIndex(of: old), !pinned.contains(new) else {
            return
        }
        pinned[i] = new
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
