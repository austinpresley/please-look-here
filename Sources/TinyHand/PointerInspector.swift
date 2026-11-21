import AppKit
import SwiftUI

struct PointerInspector: View {
    @ObservedObject var model: SettingsModel
    @State private var confirmingRemoval = false
    @State private var renaming = false
    @State private var name = ""
    @State private var resetConfirmation = false
    @State private var undoValue: PointerOverride?
    @State private var undoID: String?
    @State private var message: String?
    private var state: PointerInspectorState { model.pointerInspector }
    private var style: PointerStyle { state.style }
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            PointerPreview(configuration: state.preview, compact: state.isDefaults, inspector: true)
            HStack(spacing: Space.xs) {
                Text(state.title).font(.system(size: 14, weight: .semibold)).lineLimit(1).help(state.title)
                Spacer(minLength: 0)
                if state.pointerActions {
                    PointerStar(style: style, model: model)
                    Menu { more } label: { Image(systemName: "ellipsis.circle").frame(width: 28, height: 28) }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("More actions for \(style.title)")
                        .accessibilityLabel("More actions for \(style.title)")
                }
            }
            Picker("Edit scope", selection: $model.pointerInspector.scope) {
                Text("This").tag(PointerInspectorState.Scope.this)
                Label("Defaults", systemImage: "slider.horizontal.3").tag(PointerInspectorState.Scope.defaults)
            }.labelsHidden().pickerStyle(.segmented)
                .overlay(alignment: .leading) { PointerArtwork(style: style, side: 16).padding(.leading, Space.xxl).allowsHitTesting(false) }
            if !state.handControls { Text(state.sizeLabel).font(.system(size: 11)).foregroundStyle(.secondary) }
            PointerCustomization(style: style, model: model, defaults: state.isDefaults)
            if state.gestures { GestureInspectorTiles(style: style, model: model) }
            Text("EVERY POINTER").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(.top, Space.xs)
            EveryPointerInspector(model: model)
            if let message { Text(message).font(.system(size: 11)).foregroundStyle(.secondary) }
            if undoValue != nil && undoID == style.rawValue {
                Button("Undo Reset") { undoReset() }.font(.callout)
            }
            if let receipt = model.artworkRecovery {
                Button("Undo Restore Artwork") { model.undoArtwork(receipt) }.font(.callout)
            }
        }
        .alert("Remove \(style.title)?", isPresented: $confirmingRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove Hand", role: .destructive) { model.removeHand(style) }
        } message: { Text("A recovery copy keeps this hand, gesture artwork and settings. Undo Remove is available in the library.") }
        .alert("Rename hand", isPresented: $renaming) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { model.renameHand(style, name: name) }
        }
        .alert("Use Pointer defaults for \(style.title)?", isPresented: $resetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Use Defaults") { reset() }
        } message: { Text("Appearance and sound will follow shared defaults. Gesture artwork stays as it is. Undo is available here.") }
    }
    @ViewBuilder private var more: some View {
        let enabled = !Preferences.disabledPointerIDs.contains(style.rawValue)
        Button(enabled ? "Hide from Lists" : "Show in Lists") { model.setPointerEnabled(!enabled, for: style) }
        if style.isCustom { Button("Rename…") { name = style.title; renaming = true } }
        if style.assetName != nil { Button("Restore Artwork…") { model.choosePointerArtwork(style) } }
        if style.assetName == nil {
            let overrides = (try? PointerConfigurationDocument.load(from: Preferences.storage).pointers[style.rawValue]) ?? PointerOverride()
            Menu("Sound and effects") {
                Toggle("Tap sound · \(overrides.soundEnabled == nil ? "Default" : "Customized")", isOn: model.binding({ Preferences.pointerConfiguration(for: style.rawValue).soundEnabled }, { value in
                    model.editPointer(style) { $0.soundEnabled = value }
                }))
                Button("Use Default Tap Sound") { model.resetPointer(style, field: .soundEnabled) }.disabled(overrides.soundEnabled == nil)
                Picker("Sound choice · \(overrides.sound == nil ? "Default" : "Customized")", selection: model.binding({ Preferences.pointerConfiguration(for: style.rawValue).sound }, { value in
                    model.editPointer(style) { $0.sound = value }
                })) { ForEach(TapSoundChoice.allCases, id: \.self) { Text($0.title).tag($0) } }
                Button("Use Default Sound Choice") { model.resetPointer(style, field: .sound) }.disabled(overrides.sound == nil)
                Button("Preview Sound") { model.preview(Preferences.pointerConfiguration(for: style.rawValue).sound) }
                if style == .presentation {
                    Toggle("Shadow · \(overrides.shadow == nil ? "Default" : "Customized")", isOn: model.binding({ Preferences.pointerConfiguration(for: style.rawValue).shadow }, { value in
                        model.editPointer(style) { $0.shadow = value }
                    }))
                    Button("Use Default Shadow") { model.resetPointer(style, field: .shadow) }.disabled(overrides.shadow == nil)
                }
            }
        }
        Divider()
        Button("Reset Appearance & Sound…") { resetConfirmation = true }
        PointerFavoriteActions(style: style, model: model)
        if style.isCustom { Divider(); Button("Remove…", role: .destructive) { confirmingRemoval = true } }
    }
    private func reset() {
        do {
            undoValue = try PointerConfigurationDocument.load(from: Preferences.storage).pointers[style.rawValue] ?? PointerOverride()
            undoID = style.rawValue
            try Preferences.updatePointer(style.rawValue) { $0 = PointerOverride() }
            message = "Appearance and sound reset."; model.refresh()
        } catch { message = error.localizedDescription }
    }
    private func undoReset() {
        guard let old = undoValue, undoID == style.rawValue else { return }
        do {
            let current = try PointerConfigurationDocument.load(from: Preferences.storage).pointers[style.rawValue] ?? PointerOverride()
            guard current.isEmpty else { message = "This pointer changed after reset. Undo would replace newer values."; return }
            try Preferences.updatePointer(style.rawValue) { $0 = old }; undoValue = nil; message = nil; model.refresh()
        } catch { message = error.localizedDescription }
    }
}

private struct GestureInspectorTiles: View {
    let style: PointerStyle
    @ObservedObject var model: SettingsModel
    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "hand.raised").foregroundStyle(.secondary).help("Gesture artwork and shortcuts")
            Spacer()
            ForEach(HandGestureSlot.allCases, id: \.self) { slot in
                Menu {
                    Button("Import Artwork…") { model.chooseGestureFile(slot, for: style) }
                    Button("Use \(slot.stockTitle) Pose") { model.restoreGesture(slot, for: style) }
                        .disabled(!HandGestureCatalog.hasCustom(slot, style: style))
                    Divider()
                    Button("Shortcut…") { model.focusShortcut(command: slot.action.rawValue) }
                } label: {
                    Image(nsImage: gestureImage(slot))

                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("Edit \(slot.title) for \(style.title)").help("\(slot.title): import or restore artwork, or assign a shortcut")
            }
        }.padding(Space.sm).background(RoundedRectangle(cornerRadius: Space.sm).fill(Color.primary.opacity(0.045)))
        if let message = model.gestureMessage { Text(message).font(.system(size: 11)).foregroundStyle(.secondary) }
    }
    private func gestureImage(_ slot: HandGestureSlot) -> NSImage {
        let source: NSImage?
        if let base = style.assetName.flatMap(HandAsset.load), let image = HandGestureCatalog.image(slot, style: style) { source = base.replacingImage(image).thumbnail }
        else {
            let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            source = NSImage(systemSymbolName: "photo.badge.exclamationmark", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [dark ? .white : .black]))
        }
        return fittedPointerImage(source, side: 44, editBadge: true)
    }

}

private struct EveryPointerInspector: View {
    @ObservedObject var model: SettingsModel
    @State private var motionMore = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.sm) {
                Button { Preferences.soundMuted.toggle(); model.refresh() } label: {
                    Image(systemName: Preferences.soundMuted ? "speaker.slash.fill" : "speaker.wave.2.fill").frame(width: 28, height: 28)
                }.buttonStyle(.plain).accessibilityLabel(Preferences.soundMuted ? "Unmute all app sounds" : "Mute all app sounds")
                    .help(Preferences.soundMuted ? "Unmute all app sounds" : "Mute all app sounds")
                Slider(value: model.binding({ Preferences.soundVolume }, { Preferences.soundVolume = $0 }), in: 0...1).accessibilityLabel("App sound volume")
                Text("\(Int((Preferences.soundVolume * 100).rounded()))%").font(.system(size: 11)).monospacedDigit().frame(width: 36)
            }.padding(Space.sm)
            Divider()
            HStack(spacing: Space.sm) {
                Image(systemName: "waveform.path").frame(width: 28).help("Pointer follow style")
                Spacer(minLength: 0)
                Picker("Follow style", selection: model.binding({ Preferences.pointerMotion }, { Preferences.pointerMotion = $0 })) {
                    ForEach(PointerMotion.allCases, id: \.self) { Text($0.title).tag($0) }
                }.labelsHidden().frame(width: 120)
                Button { motionMore.toggle() } label: { Image(systemName: "ellipsis").frame(width: 28, height: 28) }
                    .buttonStyle(.plain).help("Tap swing and hand visibility").accessibilityLabel("More motion settings")
                    .popover(isPresented: $motionMore) {
                        VStack(alignment: .leading, spacing: Space.md) {
                            Text("Tap swing: \(Preferences.tapSwing < 0.01 ? "Off" : String(format: "%.1f×", Preferences.tapSwing))").font(.callout)
                            Slider(value: model.binding({ Preferences.tapSwing }, { Preferences.tapSwing = $0 }), in: 0...2, step: 0.1).accessibilityLabel("Tap swing")
                            Toggle("Hand stays on click", isOn: model.binding({ Preferences.interactKeepsHand }, { Preferences.interactKeepsHand = $0 }))
                            Text("Reduce Motion turns swing off. Drags touch down immediately.").font(.callout).foregroundStyle(.secondary)
                        }.padding(Space.lg).frame(width: 264)
                    }
            }.padding(Space.sm)
        }.background(RoundedRectangle(cornerRadius: Space.sm).fill(Color.primary.opacity(0.045)))
    }
}
