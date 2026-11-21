import SwiftUI

/// All five overrides remain independent. Defaults edits only shared values.
struct PointerCustomization: View {
    let style: PointerStyle
    @ObservedObject var model: SettingsModel
    var defaults = false
    @State private var errorMessage: String?
    private var effective: EffectivePointerConfiguration { defaults ? Preferences.pointerDefaults : Preferences.pointerConfiguration(for: style.rawValue) }
    private var value: PointerOverride { (try? PointerConfigurationDocument.load(from: Preferences.storage).pointers[style.rawValue]) ?? PointerOverride() }
    private var hands: Bool { defaults || style.assetName != nil }
    var body: some View {
        VStack(spacing: 0) {
            inspectorRow(defaults ? "Default size" : PointerConfigurationPolicy(style.rawValue).sizeLabel, symbol: "arrow.up.left.and.arrow.down.right") {
                PointerArtwork(style: defaults ? .lavender : style, side: 16)
                Slider(value: model.binding({ effective.size }, { v in change({ $0.size = v }, shared: { Preferences.pointerSize = v }) }), in: 0.04...0.20)
                    .accessibilityLabel(defaults ? "Default pointer size" : PointerConfigurationPolicy(style.rawValue).sizeLabel)
                PointerArtwork(style: defaults ? .lavender : style, side: 24)
                Text("\(Int((effective.size * 100).rounded()))%").monospacedDigit().font(.system(size: 11)).frame(width: 32)
                reset("size", customized: value.size != nil, inherited: "\(Int((Preferences.pointerDefaults.size * 100).rounded()))%") { $0.size = nil }
            }
            if hands {
                inspectorRow("Shadow", symbol: "square.2.layers.3d") {
                    Text("Shadow").font(.system(size: 11))
                    Toggle("Shadow", isOn: model.binding({ effective.shadow }, { v in change({ $0.shadow = v }, shared: { Preferences.showShadow = v }) })).labelsHidden().toggleStyle(.switch).controlSize(.small)
                    reset("shadow", customized: value.shadow != nil, inherited: Preferences.showShadow ? "On" : "Off") { $0.shadow = nil }
                }
                inspectorRow("Shadow style", symbol: "circle.lefthalf.filled") {
                    Picker("Shadow style", selection: model.binding({ effective.shadowStyle }, { v in change({ $0.shadowStyle = v }, shared: { Preferences.shadowStyle = v }) })) {
                        ForEach(PointerShadowStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 112).disabled(!effective.shadow)
                    reset("shadow style", customized: value.shadowStyle != nil, inherited: Preferences.shadowStyle.title) { $0.shadowStyle = nil }
                }
                inspectorRow("Tap sound", symbol: "hand.tap") {
                    Toggle("Tap sound", isOn: model.binding({ effective.soundEnabled }, { v in change({ $0.soundEnabled = v }, shared: { Preferences.handSound = v }) })).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        .help(Preferences.soundOutput.status(enabled: effective.soundEnabled))
                    reset("tap sound", customized: value.soundEnabled != nil, inherited: Preferences.handSound ? "On" : "Off") { $0.soundEnabled = nil }
                }
                inspectorRow("Sound choice", symbol: "music.note") {
                    Picker("Sound choice", selection: model.binding({ effective.sound }, { v in change({ $0.sound = v }, shared: { Preferences.tapSound = v }) })) {
                        ForEach(TapSoundChoice.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 96)
                    Button { model.preview(effective.sound) } label: { Image(systemName: "play.fill") }
                        .buttonStyle(.borderless).disabled(!Preferences.soundOutput.audible)
                        .accessibilityLabel("Preview sound").help("Play at app volume without enabling tap sound")
                    reset("sound choice", customized: value.sound != nil, inherited: Preferences.tapSound.title) { $0.sound = nil }
                }.id("default-sound")
            }
            if let errorMessage { Text(errorMessage).font(.callout).foregroundStyle(.red).padding(Space.sm) }
        }
        .background(RoundedRectangle(cornerRadius: Space.sm).fill(Color.primary.opacity(0.045)))
        .onChange(of: style) { _ in errorMessage = nil; model.stopPreview() }.onDisappear { model.stopPreview() }
    }
    private func inspectorRow<C: View>(_ name: String, symbol: String, @ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.xs) {
                Image(systemName: symbol).frame(width: 20).foregroundStyle(.secondary).help(name).accessibilityLabel(name)
                Spacer(minLength: 0)
                content()
            }.padding(.horizontal, Space.sm).frame(minHeight: 40)
            Divider().padding(.leading, Space.sm)
        }
    }
    @ViewBuilder private func reset(_ field: String, customized: Bool, inherited: String, changes: @escaping (inout PointerOverride) -> Void) -> some View {
        if !defaults {
            HStack(spacing: 0) {
                if customized { Circle().fill(Color.accentColor).frame(width: 4, height: 4).accessibilityLabel("Customized \(field)") }
                Button { edit(changes) } label: { Image(systemName: "arrow.counterclockwise").frame(width: 28, height: 28) }
                    .buttonStyle(.plain).disabled(!customized)
                    .accessibilityLabel("Reset \(field) to inherited \(inherited)")
                    .help("\(customized ? "Customized. Reset to" : "Follows") Pointer defaults: \(inherited)")
            }
        }
    }
    private func change(_ changes: (inout PointerOverride) -> Void, shared: () -> Void) {
        if defaults { shared(); model.refresh() } else { edit(changes) }
    }
    private func edit(_ changes: (inout PointerOverride) -> Void) {
        do { try Preferences.updatePointer(style.rawValue, changes); errorMessage = nil; model.refresh() }
        catch { errorMessage = error.localizedDescription }
    }
}
