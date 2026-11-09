import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

struct SoundPage: View {
    @ObservedObject var model: SettingsModel
    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 140), spacing: 8)]

    var body: some View {
        let on = Preferences.handSound
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tap sound")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                LazyVGrid(columns: columns, spacing: 8) {
                    SoundTile(title: "Off", symbol: "speaker.slash.fill", selected: !on) {
                        Preferences.handSound = false
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
                Row("Laser dot taps too", detail: "Off by default, for quiet pointing.") {
                    Toggle("", isOn: model.binding({ Preferences.laserSound }, { Preferences.laserSound = $0 }))
                        .toggleStyle(.switch).labelsHidden().focusable(false)
                        .disabled(!on)
                }
            }
            .opacity(on ? 1 : 0.5)
        }
        .onAppear { model.warmPreview() }
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
            .padding(3)
            .overlay(Circle().strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2))
            .scaleEffect(hovering && !selected ? 1.08 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
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
                    .frame(height: 22)
                Text(title)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(hovering ? 0.07 : 0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering = $0 }
    }
}


struct AboutPage: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                if let icon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: icon).resizable().frame(width: 72, height: 72)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("TinyHand").font(.system(size: 18, weight: .bold))
                    Text("Version \(version)").font(.system(size: 12)).foregroundColor(.secondary)
                    Text("A tiny hand for your Mac. Free and open source.").font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                if let updater = model.updater {
                    PillButton(title: "Check for Updates") { updater.checkForUpdates() }
                }
            }
            Card(title: nil) {
                LinkRow(title: "Website", detail: "tinyhand.app", url: "https://tinyhand.app")
                LinkRow(title: "Source code", detail: "github.com/nilbuild/tinyhand", url: "https://github.com/nilbuild/tinyhand")
                LinkRow(title: "Made by", detail: "@nilbuild on X", url: "https://x.com/nilbuild")
                LinkRow(title: "License", detail: "MIT", url: "https://github.com/nilbuild/tinyhand/blob/main/LICENSE")
            }
            HStack {
                Spacer()
                TextButton(title: "Reset all settings…") { model.resetAll() }
            }
        }
    }
}
