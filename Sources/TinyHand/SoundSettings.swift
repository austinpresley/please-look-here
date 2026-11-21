import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

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
                    if let hand = pointerIcon(.saved) {
                        Image(nsImage: hand).resizable().scaledToFit()
                    } else { Circle().fill(Color(cgColor: choice.resolved(for: .saved))) }
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
                    Text("By Austin Presley").font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()

            }
            Card(title: nil) {
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
                Text("Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev")").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}
