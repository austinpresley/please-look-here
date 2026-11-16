import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

struct SoundPage: View {
    @ObservedObject var model: SettingsModel
    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 140), spacing: 8)]

    var body: some View {
        let on = Preferences.handSound
        VStack(alignment: .leading, spacing: Space.xxl) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tap sound")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                LazyVGrid(columns: columns, spacing: 8) {
                    SoundTile(title: "Off", symbol: "speaker.slash.fill", selected: !on) {
                        Preferences.handSound = false
                        model.stopPreview()
                        model.refresh()
                    }
                    ForEach(TapSoundChoice.allCases, id: \.self) { choice in
                        SoundTile(title: choice.title, symbol: "waveform", selected: on && Preferences.tapSound == choice) {
                            Preferences.tapSound = choice
                            Preferences.handSound = true
                            model.preview(choice)
                            model.refresh()
                        }
                    }
                }
                Text("Click a sound to hear it. It plays each time the hand taps.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            Card(title: nil) {
                Row("Laser dot sound", detail: "Use the selected tap sound for Laser dot, independently of hand sound. Off by default.") {
                    Toggle("Laser dot tap sound", isOn: model.binding({ Preferences.laserSound }, { Preferences.laserSound = $0 }))
                        .toggleStyle(.switch).labelsHidden()
                }
            }
        }
        .onAppear { model.warmPreview() }
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


struct SoundTile: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(selected ? .accentColor : .secondary)
                    .frame(height: 24)
                Text(title)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.lg)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(hovering ? 0.07 : 0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .padding(Space.xs)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(title == "Off" ? "Turn hand sound off" : "Preview \(title) tap sound")
        .help(title == "Off" ? "Mute hand taps" : "Preview and select the \(title) tap sound")
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
