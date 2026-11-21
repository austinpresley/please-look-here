import AppKit
import ApplicationServices
import SwiftUI

struct GeneralPage: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Card(title: "Permissions") {
                permission("Accessibility", allowed: AXIsProcessTrusted(), detail: "Drawing and Quick controls") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
                }
                permission("Screen Recording", allowed: ScreenCapture.hasPermission, detail: "Capture and magnifier") {
                    ScreenCapture.openPermissionSettings()
                }
            }
            Card(title: "Startup and updates") {
                Row("Open at login") {
                    Toggle("Open at login", isOn: model.binding({ Preferences.launchAtLogin }, { Preferences.launchAtLogin = $0 }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                if let updater = model.updater {
                    TimelineView(.periodic(from: .now, by: 10)) { _ in
                        Row("Check automatically", detail: updater.lastCheckedDate.map { "Last checked \($0.formatted(date: .abbreviated, time: .shortened))." } ?? "No update check yet.") {
                            Button("Check Now") { updater.checkForUpdates() }
                            Toggle("Check for updates automatically", isOn: model.binding({ updater.automaticallyChecks }, { updater.automaticallyChecks = $0 }))
                                .labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                    }
                } else {
                    Row("Updates", detail: "Updates are not set up in this build.") { Text("Unavailable").foregroundStyle(.secondary) }
                }
            }
            Card(title: "Appearance") {
                Row("Theme") {
                    Picker("Theme", selection: model.binding({ Preferences.theme }, { Preferences.theme = $0 })) {
                        ForEach(AppTheme.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented).frame(width: 192)
                }
            }
            HStack(spacing: Space.sm) {
                Text("Getting Started").foregroundStyle(.secondary)
                Button("Practice the Controls…") { model.openPractice?(.pointer) }.buttonStyle(.link)
            }.font(.system(size: 12))
            SettingsDisclosure(title: "About Look Here Please", summary: "", symbol: "info.circle", isExpanded: $model.showingAbout) {
                AboutPage(model: model).padding(Space.md)
            }
            HStack {
                Spacer()
                Button("Reset All Settings…", role: .destructive) { model.resetAll(exportBackup: { PresetsSettingsModel().exportBackup() }) }
                    .buttonStyle(.plain).foregroundStyle(.red)
                    .padding(.horizontal, Space.md).padding(.vertical, Space.sm)
                    .background(RoundedRectangle(cornerRadius: Space.sm).fill(Color.red.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: Space.sm).strokeBorder(Color.red.opacity(0.3)))
            }
        }
    }
    private func permission(_ title: String, allowed: Bool, detail: String, action: @escaping () -> Void) -> some View {
        Row(title, detail: detail) {
            Label(allowed ? "Allowed" : "Not allowed", systemImage: allowed ? "checkmark.circle" : "exclamationmark.circle")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if !allowed { Button("Open System Settings…", action: action) }
        }
    }
}

struct ToolsSettingsPage: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            // SwiftUI's macOS segmented Picker drops Label images. Keep the
            // labeled symbols visible with native buttons in a shared strip.
            HStack(spacing: Space.xs) {
                ForEach(ToolSettingsPane.allCases) { pane in
                    Button { model.toolsPane = pane } label: {
                        Label(pane.title, systemImage: pane.symbol)
                            .font(.system(size: 12)).frame(maxWidth: .infinity).padding(.vertical, Space.xs)
                            .background(RoundedRectangle(cornerRadius: Space.xs).fill(model.toolsPane == pane ? Color(nsColor: .controlBackgroundColor) : .clear))
                    }.buttonStyle(.plain).help(pane.title)
                        .accessibilityAddTraits(model.toolsPane == pane ? .isSelected : [])
                }
            }.padding(Space.xs).background(RoundedRectangle(cornerRadius: Space.sm).fill(Color.primary.opacity(0.06)))
                .accessibilityLabel("Tool settings").accessibilityIdentifier("settings.tools.pane")
            switch model.toolsPane {
            case .drawing: DrawingPage(model: model)
            case .magnification:
                MagnificationSettings(model: model)
                recordingAccess
            case .screenshots:
                Card(title: "After capturing") {
                    Row("Destination") {
                        Picker("Screenshot destination", selection: model.binding({ ScreenshotDestination(saves: Preferences.captureSaves, copies: Preferences.captureCopies) }, { value in
                            value.apply()
                        })) {
                            ForEach(ScreenshotDestination.allCases) { destination in Text(destination.title).tag(destination) }
                        }.labelsHidden().frame(width: 176)
                    }
                    if Preferences.captureSaves {
                        Row("Save folder", detail: Preferences.captureFolder.path) { Button("Choose…") { model.chooseCaptureFolder() } }
                    }
                }
                SettingsSubtitle("Includes pointer and ink. Choose Full Display or Region when capturing.")
                recordingAccess
            }
        }
    }
    private var recordingAccess: some View {
        HStack(spacing: Space.sm) {
            Label(ScreenCapture.hasPermission ? "Screen Recording allowed" : "Screen Recording is not allowed", systemImage: ScreenCapture.hasPermission ? "checkmark.circle" : "exclamationmark.circle")
            Spacer(minLength: Space.sm)
            if !ScreenCapture.hasPermission { Button("Review Access…") { ScreenCapture.openPermissionSettings() } }
        }.font(.system(size: 12)).foregroundStyle(.secondary)
    }
}
