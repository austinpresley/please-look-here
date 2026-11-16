import SwiftUI

/// Self-contained selected-pointer details. The library can place this view next
/// to any selected catalog entry without changing selection or toolbar pins.
struct PointerCustomization: View {
    let style: PointerStyle
    @ObservedObject var model: SettingsModel
    @State private var errorMessage: String?

    private var policy: PointerConfigurationPolicy { PointerConfigurationPolicy(style.rawValue) }
    private var effective: EffectivePointerConfiguration { Preferences.pointerConfiguration(for: style.rawValue) }
    private var override: PointerOverride {
        (try? PointerConfigurationDocument.load(from: Preferences.storage).pointers[style.rawValue]) ?? PointerOverride()
    }

    var body: some View {
        Card(title: "Customize \(style.title)") {
            Row(override.isEmpty ? "Default" : "Customized", detail: "Each setting follows Pointer Defaults until you change it here.") {
                EmptyView()
            }
            Row(policy.sizeLabel, detail: status(override.size != nil)) {
                HStack(spacing: Space.sm) {
                    Slider(value: model.binding({ effective.size }, { value in edit { $0.size = value } }), in: 0.04...0.20)
                        .frame(width: 112)
                        .accessibilityLabel("\(style.title) \(policy.sizeLabel)")
                        .accessibilityValue("\(Int(effective.size * 100)) percent, \(status(override.size != nil))")
                    Text("\(Int(effective.size * 100))%").monospacedDigit()
                    useDefault(policy.sizeLabel, customized: override.size != nil) { $0.size = nil }
                }
            }
            if policy.supportsShadow {
                Row("Shadow", detail: status(override.shadow != nil)) {
                    Toggle("\(style.title) shadow", isOn: model.binding({ effective.shadow }, { value in edit { $0.shadow = value } }))
                        .labelsHidden()
                    useDefault("shadow", customized: override.shadow != nil) { $0.shadow = nil }
                }
            }
            if policy.supportsShadowStyle {
                Row("Shadow style", detail: status(override.shadowStyle != nil)) {
                    Picker("\(style.title) shadow style", selection: model.binding({ effective.shadowStyle }, { value in edit { $0.shadowStyle = value } })) {
                        ForEach(PointerShadowStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 112)
                    useDefault("shadow style", customized: override.shadowStyle != nil) { $0.shadowStyle = nil }
                }
            }
            Row("Tap sound", detail: status(override.soundEnabled != nil)) {
                Toggle("\(style.title) tap sound", isOn: model.binding({ effective.soundEnabled }, { value in edit { $0.soundEnabled = value } }))
                    .labelsHidden()
                useDefault("tap sound enabled", customized: override.soundEnabled != nil) { $0.soundEnabled = nil }
            }
            Row("Sound choice", detail: status(override.sound != nil)) {
                Picker("\(style.title) sound choice", selection: model.binding({ effective.sound }, { value in edit { $0.sound = value } })) {
                    ForEach(TapSoundChoice.allCases, id: \.self) { Text($0.title).tag($0) }
                }.labelsHidden().frame(width: 112)
                useDefault("sound choice", customized: override.sound != nil) { $0.sound = nil }
            }
            Row("Preview sound", detail: "\(Preferences.soundOutput.status(enabled: effective.soundEnabled)). Preview preserves the saved choice and tap sound setting.") {
                Button("Preview") { model.preview(effective.sound) }
                    .disabled(!Preferences.soundOutput.audible)
                    .accessibilityLabel("Preview \(style.title) sound")
                    .help("Hear \(effective.sound.title) at the app volume. Master mute also mutes Preview.")
            }
            if let errorMessage {
                Row("Unable to save pointer settings", detail: "\(errorMessage) Restore a valid pointer settings export and try again.") {
                    EmptyView()
                }
            }
        }
        .onExitCommand { model.stopPreview() }
        .onChange(of: style) { _ in errorMessage = nil; model.stopPreview() }
        .onDisappear { model.stopPreview() }
    }

    private func status(_ customized: Bool) -> String { customized ? "Customized" : "Default" }

    private func useDefault(_ field: String, customized: Bool, changes: @escaping (inout PointerOverride) -> Void) -> some View {
        Button("Use Default") { edit(changes) }
            .disabled(!customized)
            .accessibilityLabel("Use default \(field) for \(style.title)")
            .help("Follow Pointer Defaults for \(field)")
    }

    private func edit(_ changes: (inout PointerOverride) -> Void) {
        do {
            try Preferences.updatePointer(style.rawValue, changes)
            errorMessage = nil
            model.refresh()
        } catch { errorMessage = error.localizedDescription }
    }
}
