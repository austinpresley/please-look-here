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
    @Published var recovery: PresentationStore.RecoverySummary?
    @Published var recoveryCopies: [PresentationStore.RecoverySummary] = []
    @Published var importFilename = "Backup"
    @Published var importDetails = false
    private var refreshGeneration = 0
    @Published var restorePlan: PresentationStore.RestorePlan?
    @Published var included = false
    @Published var showingRecovery = false
    private let injectedStore: PresentationStore?
    init(store: PresentationStore? = nil) { injectedStore = store }
    private var store: PresentationStore { injectedStore ?? PresentationStore(directory: CustomHands.directory, storage: Preferences.storage,
        availableIDs: Set(PointerCatalog.entries.filter(\.available).map { $0.style.rawValue })) }
    private func catalogSignatures() -> [String: String] {
        Dictionary(uniqueKeysWithValues: PointerStyle.allCases.map { style in
            (style.rawValue, style.assetName.map(HandAsset.imageSignature) ?? "presentation")
        })
    }
    var selected: NamedPresentationPreset? { presets.first { $0.id == selectedID } }

    func refresh() {
        do { presets = try store.presets() }
        catch { message = error.localizedDescription }
        if selected == nil { selectedID = presets.first?.id }
        refreshGeneration += 1
        let generation = refreshGeneration, store = store
        DispatchQueue.global(qos: .utility).async {
            let result = Result { try store.resolvedRecoveryCatalogue() }
            DispatchQueue.main.async {
                guard self.refreshGeneration == generation else { return }
                switch result {
                case .success(let value): self.recoveryCopies = value.0; self.recovery = value.1
                case .failure(let error): self.message = error.localizedDescription
                }
            }
        }
    }
    private func changed(artworkChanged: Bool = false) {
        if artworkChanged {
            CustomHands.reload()
            for style in PointerStyle.allCases { if let asset = style.assetName { HandAsset.forget(asset) } }
            HandGestureCatalog.forget()
            NotificationCenter.default.post(name: CustomHands.changed, object: nil)
        }
        Preferences.notifyPointerConfigurationChanged()
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
    func rename(_ id: UUID, name: String) { perform { try store.renamePreset(id, name: name) } }
    func isCurrent(_ preset: NamedPresentationPreset) -> Bool {
        (try? PresentationSetup.capture(Preferences.storage)).map { preset.setup.matches($0) } ?? false
    }
    func reviewRestore(_ copy: PresentationStore.RecoverySummary) {
        guard !busy else { return }
        let store = store
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { () -> PresentationStore.RestorePlan in
                guard let receipt = try store.readRecovery(copy.id) else { throw PresentationArchiveError(message: "Recovery copy is missing. Nothing was replaced.") }
                return try store.previewRestore(receipt)
            }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success(let plan): self.restorePlan = plan
                case .failure(let error):
                    self.message = error.localizedDescription
                    if let index = self.recoveryCopies.firstIndex(where: { $0.id == copy.id }) { self.recoveryCopies[index].problem = "Unreadable copy. Kept on disk. \(error.localizedDescription)" }
                }
            }
        }
    }
    func confirmRestore() {
        guard let plan = restorePlan else { return }
        do {
            _ = try store.restoreCopy(plan); restorePlan = nil
            message = "Recovery copy restored. A copy of the previous state was saved first. Undo restores it."
            changed(artworkChanged: true)
        } catch { message = error.localizedDescription; restorePlan = nil }
    }
    func apply() { if let selected { perform { try store.applyPreset(selected) } } }
    func update() { if let selected { perform { try store.savePreset(name: selected.name, replacing: selected.id) } } }
    func remove() { if let selected { perform { try store.removePreset(selected.id) } } }
    func undo() {
        guard let recovery else { return }
        let store = store
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try store.readRecovery(recovery.id) }
            DispatchQueue.main.async {
                self.busy = false
                do {
                    guard let receipt = try result.get() else { throw PresentationArchiveError(message: "Recovery copy is missing.") }
                    try store.restore(receipt)
                    self.message = "\(receipt.title) undone. Its local recovery copy is retained."
                    self.changed(artworkChanged: true)
                } catch {
                    self.message = error.localizedDescription
                    self.refresh()
                }
            }
        }
    }
    func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Look Here Please Backup.json"
        panel.message = "Includes supported settings, saved presets, custom hands, restored built-in artwork and gesture artwork. Shortcuts, startup and screenshot folders stay on this Mac."
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
                case .success(let plan): self.importFilename = url.lastPathComponent; self.importDetails = false; self.importPlan = plan; self.message = nil
                case .failure(let error): self.message = error.localizedDescription
                }
            }
        }
    }
    func confirmImport() {
        guard let importPlan, !busy else { return }
        busy = true
        let store = store
        let catalogAtPreparation = catalogSignatures()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try store.prepareImport(importPlan) }
            DispatchQueue.main.async {
                self.busy = false
                do {
                    let prepared = try result.get()
                    // Recheck catalog file signatures without causing a newly
                    // changed image to decode on main. Preference/file validation
                    // and publication then share native/control writers' queue.
                    defer { DispatchQueue.global(qos: .utility).async { store.discardImport(prepared) } }
                    guard self.catalogSignatures() == catalogAtPreparation else {
                        throw PresentationArchiveError(message: "The pointer library changed after preview. Preview the backup again before importing. Nothing was replaced.")
                    }
                    try store.commitImport(prepared)
                    self.importPlan = nil
                    self.message = "Backup imported. Undo restores the previous setup and files."
                    self.changed(artworkChanged: true)
                } catch { self.message = error.localizedDescription; self.importPlan = nil }
            }
        }
    }
}

enum PresentationBackupContents {
    static let included = ["Presets", "Pointer, ink and sound settings", "Custom hand and gesture artwork", "Restored built-in hand artwork"]
    static let localOnly = ["Shortcuts", "Capture folder, startup and window positions"]
}

struct PresetsPage: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject var model: PresetsSettingsModel
    @State private var saving = false
    @State private var removing = false
    @State private var removalID: UUID?
    @State private var renameID: UUID?
    @State private var renameName = ""

    init(settings: SettingsModel) { self.settings = settings; self.model = settings.presetsModel }
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Card(title: nil) {
                Row("Undo last change", detail: model.recovery.map { "Before \($0.title). Kept after restart." } ?? "No changes to undo yet.", symbol: "arrow.uturn.backward") {
                    Button("Undo") { model.undo() }.disabled(model.recovery == nil)
                }
            }.gridProbe("presets.undo", area: "presets")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: Space.md)], alignment: .leading, spacing: Space.md) {
                ForEach(model.presets) { preset in presetCard(preset) }
                Button { model.name = ""; saving = true } label: {
                    VStack(spacing: Space.md) {
                        Image(systemName: "plus").font(.system(size: 24, weight: .light))
                        Text("Save current").font(.system(size: 12))
                    }.frame(maxWidth: .infinity).frame(height: 176)
                        .background(RoundedRectangle(cornerRadius: Space.md).strokeBorder(Color.primary.opacity(0.16)))
                        .contentShape(RoundedRectangle(cornerRadius: Space.md))
                }.buttonStyle(.plain).help("Save the current pointer, ink and sound setup")
            }.gridProbe("presets.cards", area: "presets")
            Card(title: "Backup") {
                Row("Presets and artwork", symbol: "square.stack") {
                    Button { model.exportBackup() } label: { Label("Export…", systemImage: "square.and.arrow.up") }
                    Button { model.importBackup() } label: { Label("Import…", systemImage: "square.and.arrow.down") }
                }
            }.gridProbe("presets.backup", area: "presets")
            SettingsDisclosure(title: "What's included", summary: "", symbol: "checkmark.shield", isExpanded: $model.included) {
                VStack(alignment: .leading, spacing: Space.md) {
                    ForEach(PresentationBackupContents.included, id: \.self) { Label($0, systemImage: "checkmark").font(.system(size: 12)) }
                    ForEach(PresentationBackupContents.localOnly, id: \.self) { Label("\($0) · stay on this Mac", systemImage: "xmark").font(.system(size: 12)).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(Space.md)
            }.gridProbe("presets.included", area: "presets")
            SettingsDisclosure(title: "Recovery copies", summary: "\(model.recoveryCopies.count)", symbol: "folder.badge.gearshape", isExpanded: $model.showingRecovery) {
                if model.recoveryCopies.isEmpty { Row("No recovery copies yet") { EmptyView() } }
                ForEach(model.recoveryCopies) { copy in
                    Row("Before \(copy.title)", detail: copy.problem ?? copy.created.formatted(date: .abbreviated, time: .shortened), symbol: copy.problem == nil ? "clock.arrow.circlepath" : "exclamationmark.triangle") {
                        Button("Restore…") { model.reviewRestore(copy) }.disabled(copy.problem != nil)
                    }
                }
                Text("Restore saves a copy of the current state first.").font(.system(size: 11)).foregroundStyle(.secondary).padding(Space.md)
            }.gridProbe("presets.recovery", area: "presets")
            if model.busy { ProgressView().controlSize(.small).accessibilityLabel("Preparing backup") }
            if let message = model.message { Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) }
        }
        .gridArea("presets", inset: 0)
        .disabled(model.busy).onAppear { model.refresh() }
        .alert("Remove this preset?", isPresented: $removing) {
            Button("Cancel", role: .cancel) {}
            Button("Remove Preset", role: .destructive) { if let id = removalID { model.selectedID = id; model.remove() } }
        } message: { Text("A local recovery copy retains this preset. Undo last change restores it.") }
        .alert("Rename preset", isPresented: Binding(get: { renameID != nil }, set: { if !$0 { renameID = nil } })) {
            TextField("Preset name", text: $renameName)
            Button("Cancel", role: .cancel) { renameID = nil }
            Button("Rename") { if let id = renameID { model.rename(id, name: renameName) }; renameID = nil }
                .disabled(renameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .sheet(isPresented: $saving) { saveSheet }
        .sheet(isPresented: Binding(get: { model.importPlan != nil }, set: { if !$0 && !model.busy { model.importPlan = nil } })) {
            if let plan = model.importPlan { ImportPresentationPreview(model: model, preview: plan.preview) }
        }
        .sheet(isPresented: Binding(get: { model.restorePlan != nil }, set: { if !$0 { model.restorePlan = nil } })) {
            if let plan = model.restorePlan { RestorePresentationPreview(model: model, plan: plan) }
        }
    }
    private func presetCard(_ preset: NamedPresentationPreset) -> some View {
        let now = model.isCurrent(preset)
        let style = PointerStyle(rawValue: preset.setup.selectedID)
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .top) {
                Button { model.selectedID = preset.id } label: {
                    Group {
                        if let style { PointerArtwork(style: style, side: 56) }
                        else { Image(systemName: "photo.badge.exclamationmark").frame(width: 56, height: 56) }
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Select \(preset.name)")
                Menu {
                    Button("Update from Current") { model.selectedID = preset.id; model.update() }
                    Button("Rename…") { renameName = preset.name; renameID = preset.id }
                    Button("Remove…", role: .destructive) { removalID = preset.id; removing = true }
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("More actions for \(preset.name)")
                    .accessibilityLabel("More actions for \(preset.name)")
            }
            HStack(spacing: Space.sm) {
                Circle().fill(presetInk(preset)).frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.2))).help("Ink color")
                Image(systemName: presetSound(preset) ? "speaker.wave.2" : "speaker.slash").help(presetSound(preset) ? "Tap sound on" : "Tap sound off")
                Label("\(preset.setup.pinnedIDs.count)", systemImage: "star.fill").help("Toolbar favorites")
            }.font(.system(size: 11)).foregroundStyle(.secondary)
            Text(preset.name).font(.system(size: 13, weight: .semibold)).lineLimit(1).help(preset.name)
            HStack {
                if now { HStack(spacing: Space.xs) { Image(systemName: "checkmark").foregroundStyle(Color.accentColor); Text("Now").foregroundStyle(.primary) }.font(.system(size: 11)) }
                Spacer(minLength: 0)
                Button { model.selectedID = preset.id; model.apply() } label: { Label("Apply", systemImage: "checkmark.circle") }
                    .controlSize(.small).disabled(now).help(now ? "Already in use" : "Apply \(preset.name)")
            }
        }.padding(Space.md).frame(maxWidth: .infinity).frame(height: 176, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: Space.md).fill(now ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.045)))
            .overlay(RoundedRectangle(cornerRadius: Space.md).strokeBorder(now ? Color.accentColor : model.selectedID == preset.id ? Color.primary.opacity(0.35) : .clear, lineWidth: now ? 2 : 1))
    }
    private func presetInk(_ preset: NamedPresentationPreset) -> Color {
        let choice: InkChoice
        if case .string(let value) = preset.setup.settings["inkChoice"] { choice = InkChoice(rawValue: value) ?? .match } else { choice = .match }
        return Color(cgColor: choice.resolved(for: PointerStyle(rawValue: preset.setup.selectedID) ?? .lavender))
    }
    private func presetSound(_ preset: NamedPresentationPreset) -> Bool {
        let document = try? PointerConfigurationDocument.decode(preset.setup.pointerOverrides)
        return (document?.pointers[preset.setup.selectedID]?.soundEnabled ?? (preset.setup.settings["sound.hands"] == .bool(true))) && preset.setup.settings["sound.muted"] != .bool(true)
    }
    private var saveSheet: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Save Current Setup").font(.title2.bold())
            TextField("Preset name", text: $model.name).textFieldStyle(.roundedBorder).onSubmit { savePreset() }
            if let message = model.message { Text(message).font(.callout).foregroundStyle(.secondary) }
            HStack {
                Spacer()
                Button("Cancel") { saving = false }.keyboardShortcut(.cancelAction)
                Button("Save Preset") { savePreset() }.keyboardShortcut(.defaultAction)
                    .disabled(model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(Space.xxl).frame(width: 480)
    }
    private func savePreset() {
        guard !model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        model.save(); if model.name.isEmpty { saving = false }
    }
}

private struct RestorePresentationPreview: View {
    @ObservedObject var model: PresetsSettingsModel
    let plan: PresentationStore.RestorePlan
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Restore Recovery Copy").font(.title2.bold())
            Text("Before \(plan.receipt.title), \(plan.receipt.created.formatted(date: .abbreviated, time: .shortened)).")
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Settings to replace").font(.headline)
                    Text(plan.changedSettings.isEmpty ? "No setting differences." : plan.changedSettings.joined(separator: "\n"))
                    Text("Files to replace or remove").font(.headline)
                    Text(plan.replacedFiles.isEmpty ? "No artwork or preset files." : (plan.presetChanges + plan.replacedFiles.filter { $0 != ".Presentation/presets.json" }.map(fileTitle)).joined(separator: "\n"))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Label("A recovery copy of the current state is saved first.", systemImage: "checkmark.shield")
            Text("Replaces portable pointer, ink and sound settings and the listed preset or artwork files. Shortcuts, capture folder, startup and window positions stay on this Mac.").font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { model.restorePlan = nil }.keyboardShortcut(.cancelAction)
                Button("Restore Copy") { model.confirmRestore() }.keyboardShortcut(.defaultAction)
            }
        }.padding(Space.xxl).frame(width: 480, height: 480)
    }
    private func fileTitle(_ path: String) -> String {
        if path == ".Presentation/presets.json" { return "Saved presets" }
        if path == "hands.json" { return "Custom hand library" }
        if path.hasPrefix("Gestures/") {
            let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            let slot = name.hasSuffix("-first") ? "Gesture 1" : "Gesture 2"
            let id = String(name.dropLast(name.hasSuffix("-first") ? 6 : 7))
            return "\(slot) artwork for \(PointerStyle(rawValue: id)?.title ?? "a saved hand")"
        }
        let id = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        return "Hand artwork for \(PointerStyle(rawValue: id)?.title ?? "a saved hand")"
    }
}

private struct ImportPresentationPreview: View {
    @ObservedObject var model: PresetsSettingsModel
    let preview: PresentationStore.Preview
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Import \(model.importFilename)").font(.title2.bold()).lineLimit(2)
                .gridProbe("presets.import.title", area: "presets.import")
            Label("A recovery copy is saved before any changes.", systemImage: "checkmark.shield")
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    if !preview.changedSettings.isEmpty { detail("Settings to replace", preview.changedSettings) }
                    if !preview.addedHands.isEmpty { detail("New hands", preview.addedHands) }
                    if !preview.addedArtwork.isEmpty { detail("New artwork", preview.addedArtwork) }
                    if !preview.addedPresets.isEmpty { detail("New presets", preview.addedPresets) }
                    DisclosureGroup("Details", isExpanded: $model.importDetails) {
                        VStack(alignment: .leading, spacing: Space.md) {
                            Text("Selected pointer: \(pointerName(preview.selectedID))")
                            detail("Toolbar pins in order", preview.pinnedIDs.map(pointerName))
                            detail("Disabled pointers", preview.disabledIDs.map(pointerName))
                            detail("Customized pointers", preview.overrideIDs.map(pointerName))
                        }.padding(.top, Space.sm)
                    }
                    if !preview.conflicts.isEmpty { detail("Resolve these conflicts before importing", preview.conflicts) }
                    Text("Pointer On/Off and Cursor or drawing mode stay as they are. Shortcuts, startup and screenshot folders stay on this Mac. Existing files are kept.")
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
    private func pointerName(_ id: String) -> String {
        PointerStyle(rawValue: id)?.title ?? model.importPlan?.archive.hands.first(where: { $0.id == id })?.name ?? "Unavailable pointer"
    }
    private func detail(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title).font(.headline)
            Text(items.isEmpty ? "None" : items.joined(separator: "\n")).textSelection(.enabled)
        }
    }
}
