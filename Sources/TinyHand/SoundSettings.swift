import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

struct SoundPage: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            Card(title: "App Sound") {
                Row("Mute all sounds", detail: "Preserves pointer choices and tap sound settings. Also mutes Preview.") {
                    Toggle("Mute all sounds", isOn: model.binding({ Preferences.soundMuted }, { Preferences.soundMuted = $0 }))
                        .labelsHidden().toggleStyle(.switch)
                }
                Row("Volume", detail: Preferences.soundOutput.status(enabled: true)) {
                    HStack(spacing: Space.sm) {
                        Slider(value: model.binding({ Preferences.soundVolume }, { Preferences.soundVolume = $0 }), in: 0...1)
                            .frame(width: 144)
                            .accessibilityLabel("App sound volume")
                            .accessibilityValue("\(Int((Preferences.soundVolume * 100).rounded())) percent")
                        Text("\(Int((Preferences.soundVolume * 100).rounded()))%")
                            .monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                }
            }
            Card(title: "Pointer Defaults") {
                Row("Tap sound", detail: "Shared setting for pointers that use defaults. Customize individual pointers in Pointers.") {
                    Toggle("Default tap sound enabled", isOn: model.binding({ Preferences.handSound }, { Preferences.handSound = $0 }))
                        .labelsHidden().toggleStyle(.switch)
                }
                Row("Sound choice", detail: "Selecting a sound saves the choice. Use Preview to hear it.") {
                    Picker("Default sound choice", selection: model.binding({ Preferences.tapSound }, { Preferences.tapSound = $0 })) {
                        ForEach(TapSoundChoice.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 144)
                }
                Row("Preview", detail: "Hear the selected sound without enabling tap sound.") {
                    Button("Preview") { model.preview(Preferences.tapSound) }
                        .disabled(!Preferences.soundOutput.audible)
                        .accessibilityLabel("Preview default tap sound")
                        .help("Hear the selected sound at the app volume. Master mute also mutes Preview.")
                }
                Row("Current pointer", detail: "\(PointerStyle.saved.title): \(Preferences.soundOutput.status(enabled: Preferences.pointerConfiguration(for: PointerStyle.saved.rawValue).soundEnabled))") {
                    EmptyView()
                }
            }
        }
        .onExitCommand { model.stopPreview() }
        .onDisappear { model.stopPreview() }
    }
}


struct InkSwatch: View {
    let choice: InkChoice
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let color = choice.color {
                    Circle().fill(Color(cgColor: color))
                        .overlay(Circle().strokeBorder(Color.primary.opacity(choice == .black ? 0.35 : 0.15), lineWidth: 1))
                } else {
                    Circle().fill(AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center))
                }
            }
            .frame(width: 20, height: 20)
            .padding(Space.xs)
            .overlay(Circle().strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2))
            .overlay(alignment: .bottomTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.primary, Color(nsColor: .windowBackgroundColor))
                        .font(.system(size: 12, weight: .bold))
                        .accessibilityHidden(true)
                }
            }
            .scaleEffect(hovering && !selected ? 1.08 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Ink color: \(choice.title)")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(choice.title)
        .onHover { hovering = $0 }
    }
}


struct AboutPage: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        VStack(alignment: .leading, spacing: Space.xxl) {
            HStack(spacing: 16) {
                if let icon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: icon).resizable().frame(width: 72, height: 72)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Look Here Please").font(.system(size: 18, weight: .bold))
                    Text("Version \(version)").font(.system(size: 12)).foregroundColor(.secondary)
                    Text("Point it out. Draw it on screen.").font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                if let updater = model.updater {
                    PillButton(title: "Check for Updates") { updater.checkForUpdates() }
                }
            }
            Card(title: nil) {
                Row("By Austin Presley", detail: "Hands, laser and screen annotations for your Mac.") { EmptyView() }
                LinkRow(title: "Look Here Please on GitHub", detail: "Source and project status", url: "https://github.com/austinpresley/please-look-here")
                LinkRow(title: "Based on TinyHand", detail: "Original project by Kamran Ahmed", url: "https://github.com/nilbuild/tinyhand")
                LinkRow(title: "License", detail: "MIT", url: "https://github.com/austinpresley/please-look-here/blob/main/LICENSE")
                if let notices = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt") {
                    Row("Open-source notices", detail: "Credits and licenses for adapted code, sounds and artwork.") {
                        Button("Open Notices") { NSWorkspace.shared.open(notices) }
                    }
                }
            }
            HStack {
                Spacer()
                TextButton(title: "Reset all settings…") { model.resetAll() }
            }
        }
    }
}
