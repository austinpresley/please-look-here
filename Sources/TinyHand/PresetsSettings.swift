import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Owns only the Presets page. Does not register keys, change activation or set
/// Interact. Expensive artwork decoding/export runs away from the main queue.
final class PresetsSettingsModel: ObservableObject {
    @Published var presets: [NamedPresentationPreset] = []
    @Published var selectedID: UUID?
    @Published var name = ""
    @Published var message: String?
    @Published var busy = false
    @Published var importPlan: PresentationStore.Plan?
    @Published var recovery: PresentationStore.Recovery?
    private var store: PresentationStore { PresentationStore(directory: CustomHands.directory, storage: Preferences.storage,
        availableIDs: Set(PointerCatalog.entries.filter(\.available).map { $0.style.rawValue })) }
    var selected: NamedPresentationPreset? { presets.first { $0.id == selectedID } }

    func refresh() {
        do { presets = try store.presets(); recovery = try store.latestRecovery() }
        catch { message = error.localizedDescription }
        if selected == nil { selectedID = presets.first?.id }
    }
    private func changed() {
        CustomHands.reload()
        for style in PointerStyle.allCases { if let asset = style.assetName { HandAsset.forget(asset) } }
        HandGestureCatalog.forget()
        Preferences.notifyPointerConfigurationChanged()
        NotificationCenter.default.post(name: CustomHands.changed, object: nil)
        refresh()
    }
    @discardableResult private func perform(_ action: () throws -> PresentationStore.Recovery) -> Bool {
        do {
            let receipt = try action()
            message = "\(receipt.title) completed. Undo restores the previous setup."
            changed()
            return true
        } catch { message = error.localizedDescription; return false }
    }
    func save() {
        let savedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard perform({ try store.savePreset(name: savedName) }) else { return }
        selectedID = presets.first(where: { $0.name == savedName })?.id
        name = ""
    }
    func apply() { if let selected { perform { try store.applyPreset(selected) } } }
    func update() { if let selected { perform { try store.savePreset(name: selected.name, replacing: selected.id) } } }
    func remove() { if let selected { perform { try store.removePreset(selected.id) } } }
    func undo() {
        guard let recovery else { return }
        do { try store.restore(recovery); message = "\(recovery.title) undone. Its local recovery copy is retained."; changed() }
        catch { message = error.localizedDescription }
    }
    func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Look Here Please Backup.json"
        panel.message = "Includes supported settings, saved presets, custom hands and gesture artwork. Shortcuts, startup and screenshot folders stay on this Mac."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let store = store
        busy = true; message = "Preparing backup…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try store.captureArchive().encoded().write(to: url, options: .atomic) }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success: self.message = "Backup exported to \(url.lastPathComponent)."
                case .failure(let error): self.message = error.localizedDescription
                }
            }
        }
    }
    func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        panel.message = "Choose a Look Here Please backup. Review all changes before importing."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = true; message = "Validating backup…"
        let store = store
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { () -> PresentationStore.Plan in
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true,
                      let size = values.fileSize, size <= PortablePresentationArchive.maximumBytes else {
                    throw PresentationArchiveError(message: "Choose a regular JSON backup no larger than 100 MB.")
                }
                return try store.preview(PortablePresentationArchive.decode(Data(contentsOf: url)))
            }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success(let plan): self.importPlan = plan; self.message = nil
                case .failure(let error): self.message = error.localizedDescription
                }
            }
        }
    }
    func confirmImport() {
        guard let importPlan, !busy else { return }
        busy = true
        let store = store
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try store.apply(importPlan) }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success:
                    self.importPlan = nil
                    self.message = "Backup imported. Undo restores the previous setup and files."
                    self.changed()
                case .failure(let error): self.message = error.localizedDescription; self.importPlan = nil
                }
            }
        }
    }
}

struct PresetsPage: View {
    @StateObject private var model = PresetsSettingsModel()
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            Text("Save named pointer, drawing and sound setups. Applying a preset keeps Pointer On/Off, Interact, shortcuts and startup as they are.")
                .font(.callout).foregroundStyle(.secondary)
            Card(title: "Saved presets") {
                Row("Save current setup") {
                    TextField("Preset name", text: $model.name).frame(width: 160)
                        .accessibilityLabel("New preset name")
                        .onSubmit { if !model.busy { model.save() } }
                    Button("Save") { model.save() }.disabled(model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if model.presets.isEmpty {
                    Text("No saved presets. Name the current setup above to save it.")
                        .font(.callout).foregroundStyle(.secondary).padding(Space.lg)
                } else {
                    Row("Preset") {
                        Picker("Preset", selection: $model.selectedID) {
                            ForEach(model.presets) { preset in Text(preset.name).tag(Optional(preset.id)) }
                        }.labelsHidden().frame(maxWidth: 240)
                    }
                    HStack(spacing: Space.sm) {
                        Button("Apply") { model.apply() }
                        Button("Update from Current Setup") { model.update() }
                        Button("Remove") { model.remove() }
                    }.padding(Space.lg).disabled(model.selected == nil)
                    if let selected = model.selected {
                        Text("Selected pointer: \(selected.setup.selectedID). \(selected.setup.pinnedIDs.count) toolbar pins. \(selected.setup.disabledIDs.count) disabled pointers. Missing pointer settings stay saved; the app uses an available pointer until artwork is restored.")
                            .font(.callout).foregroundStyle(.secondary).padding(Space.lg)
                    }
                }
            }
            Card(title: "Portable backup") {
                Row("Settings and artwork", detail: "Includes custom hands, gestures, saved presets, Pointer Defaults, per-pointer overrides and App Sound.") {
                    Button("Export…") { model.exportBackup() }
                    Button("Import…") { model.importBackup() }
                }
                Text("Shortcuts, startup, screenshot folders and display positions are excluded. Existing hands and artwork are kept. Imports with conflicts stop before making changes.")
                    .font(.callout).foregroundStyle(.secondary).padding(Space.lg)
            }
            if let recovery = model.recovery {
                Card(title: "Recovery") {
                    Row(recovery.title, detail: "A local recovery copy survives closing Settings and restarting the app.") {
                        Button("Undo Last Change") { model.undo() }
                    }
                    Text("Recovery folder: \(CustomHands.directory.appendingPathComponent(".Presentation/Recovery").path)")
                        .font(.callout).foregroundStyle(.secondary).textSelection(.enabled).padding(Space.lg)
                }
            }
            if model.busy { ProgressView().controlSize(.small).accessibilityLabel("Preparing backup") }
            if let message = model.message { Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) }
        }
        .disabled(model.busy)
        .onAppear { model.refresh() }
        .sheet(isPresented: Binding(get: { model.importPlan != nil }, set: { if !$0 && !model.busy { model.importPlan = nil } })) {
            if let plan = model.importPlan { ImportPresentationPreview(model: model, preview: plan.preview) }
        }
    }
}

private struct ImportPresentationPreview: View {
    @ObservedObject var model: PresetsSettingsModel
    let preview: PresentationStore.Preview
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Import Backup").font(.title2.bold())
                .gridProbe("presets.import.title", area: "presets.import")
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("\(preview.addedHands.count) new hands, \(preview.addedArtwork.count) new artwork files, \(preview.addedPresets.count) new presets.")
                    detail("Settings to replace", preview.changedSettings)
                    detail("New hands", preview.addedHands)
                    detail("New artwork", preview.addedArtwork)
                    detail("New presets", preview.addedPresets)
                    Text("Selected pointer: \(preview.selectedID)")
                    detail("Toolbar pins in order", preview.pinnedIDs)
                    detail("Disabled pointers", preview.disabledIDs)
                    detail("Override IDs, including missing pointers", preview.overrideIDs)
                    if !preview.conflicts.isEmpty { detail("Resolve these conflicts before importing", preview.conflicts) }
                    Text("Pointer On/Off and Interact stay as they are. Shortcuts, startup and screenshot folders stay on this Mac. Existing files are kept. A local recovery copy is saved before changes are applied.")
                        .foregroundStyle(.secondary)
                    Text("If the selected pointer is missing or unavailable, the app chooses an enabled available pointer. Its saved pins and overrides remain in the setup.")
                        .foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("Cancel") { model.importPlan = nil }.keyboardShortcut(.cancelAction).disabled(model.busy)
                Button(model.busy ? "Importing…" : "Import Backup") { model.confirmImport() }
                    .keyboardShortcut(.defaultAction).disabled(!preview.canApply || model.busy)
            }
        }.padding(Space.xxl).frame(width: 640, height: 560)
            .gridArea("presets.import", inset: Space.xxl).interactiveDismissDisabled(model.busy)
    }
    private func detail(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title).font(.headline)
            Text(items.isEmpty ? "None" : items.joined(separator: "\n")).textSelection(.enabled)
        }
    }
}
