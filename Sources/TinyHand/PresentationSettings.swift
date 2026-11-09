import AppKit
import ApplicationServices
import SwiftUI

struct GeneralPage: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            Card(title: "Using the pointer") {
                Row("Pointer mode", detail: "Point uses apps normally. Draw adds annotations.") {
                    Picker("Pointer mode", selection: model.binding({ Preferences.pointerMode }, { mode in
                        if model.applyMode?(mode) == false { model.generalMessage = "Allow Accessibility to use Draw. Point is still available." }
                        else if model.applyMode == nil { Preferences.pointerMode = mode }
                    })) {
                        ForEach(PointerMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 144)
                }
                Row("Hold to use apps in Draw", detail: "Temporarily pass clicks and drags through.") {
                    Picker("Interaction key", selection: model.binding({ Preferences.interactKey }, { Preferences.interactKey = $0 })) {
                        ForEach(InteractKey.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().fixedSize()
                }
                Row("Keep the hand while interacting") {
                    Toggle("Keep the hand while interacting", isOn: model.binding({ Preferences.interactKeepsHand }, { Preferences.interactKeepsHand = $0 })).labelsHidden().toggleStyle(.switch)
                }
            }
            if let message = model.generalMessage { Text(message).font(.callout).foregroundStyle(.secondary) }
            Card(title: "Permissions") {
                Row("Drawing", detail: AXIsProcessTrusted() ? "Accessibility is allowed." : "Point works without this permission.") {
                    PillButton(title: AXIsProcessTrusted() ? "Review…" : "Allow Drawing…") {
                        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
                        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
                    }
                }
                Row("Screenshots", detail: ScreenCapture.hasPermission ? "Screen Recording is allowed." : "Requested when you take your first screenshot.") {
                    PillButton(title: "Review…") { ScreenCapture.openPermissionSettings() }
                }
            }
            Card(title: "Screenshots") {
                Row("Copy to clipboard") {
                    Toggle("Copy screenshots to clipboard", isOn: model.binding({ Preferences.captureCopies }, { Preferences.captureCopies = $0 }))
                        .labelsHidden().toggleStyle(.switch).disabled(!Preferences.captureSaves)
                }
                Row("Save screenshots") {
                    Toggle("Save screenshots", isOn: model.binding({ Preferences.captureSaves }, { Preferences.captureSaves = $0 }))
                        .labelsHidden().toggleStyle(.switch).disabled(!Preferences.captureCopies)
                }
                Row("Save folder", detail: Preferences.captureFolder.lastPathComponent) {
                    PillButton(title: "Choose…") { model.chooseCaptureFolder() }
                }
            }
            Card(title: "Startup") {
                Row("Open TinyHand when you log in") {
                    Toggle("Open at login", isOn: model.binding({ Preferences.launchAtLogin }, { Preferences.launchAtLogin = $0 })).labelsHidden().toggleStyle(.switch)
                }
                if let updater = model.updater {
                    Row("Check for updates automatically") {
                        Toggle("Check for updates automatically", isOn: model.binding({ updater.automaticallyChecks }, { updater.automaticallyChecks = $0 })).labelsHidden().toggleStyle(.switch)
                    }
                }
            }
        }
    }
}

struct ShortcutsPage: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            Text("Presentation commands use key combinations. Tool keys work only in Draw, and pause while you type text or edit Settings.")
                .font(.callout).foregroundStyle(.secondary)
            Card(title: "Pointer and drawing") {
                Row("Turn pointer on or off") {
                    ShortcutField(shortcut: Preferences.toggleShortcut, model: model, label: "Turn pointer on or off") { model.applyToggleShortcut?($0) ?? false }
                }
                Row("Clear Drawing") {
                    ShortcutField(shortcut: Preferences.clearShortcut, model: model, label: "Clear Drawing") { model.applyClearShortcut?($0) ?? false }
                }
                ForEach(PresentationAction.allCases.filter { !$0.drawOnly }, id: \.self) { action in shortcutRow(action) }
            }
            Card(title: "Tools in Draw mode") {
                ForEach(PresentationAction.allCases.filter(\.drawOnly), id: \.self) { action in shortcutRow(action) }
                Row("Undo / Redo", detail: "Only annotations are affected while Draw is active.") {
                    Text("⌘Z / ⇧⌘Z").font(.callout).foregroundStyle(.secondary)
                }
            }
            if let error = model.shortcutError { Text(error).font(.callout).foregroundStyle(.red) }
        }
    }
    private func shortcutRow(_ action: PresentationAction) -> some View {
        Row(action.title) {
            ShortcutField(shortcut: Preferences.shortcut(for: action), model: model, label: action.title, allowsPlainKeys: action.drawOnly) {
                model.applyPresentationShortcut?(action, $0) ?? false
            }
        }
    }
}

struct AppearancePage: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            Card(title: "Appearance") {
                Row("Theme") {
                    Picker("Theme", selection: model.binding({ Preferences.theme }, { Preferences.theme = $0 })) {
                        ForEach(AppTheme.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented).frame(width: 192)
                }
            }
            Card(title: "Pointer") {
                Row("Size", detail: "Relative to the display height.") {
                    HStack(spacing: Space.sm) {
                        Slider(value: model.binding({ Double(Preferences.pointerSize) }, { Preferences.pointerSize = CGFloat($0) }),
                               in: Double(Preferences.pointerSizeRange.lowerBound)...Double(Preferences.pointerSizeRange.upperBound))
                            .frame(width: 144)
                            .accessibilityLabel("Pointer size")
                        Text("\(Int(Preferences.pointerSize * 100))%").monospacedDigit().frame(width: 36, alignment: .trailing)
                    }
                }
                Row("Shadow under the pointer") {
                    Toggle("Pointer shadow", isOn: model.binding({ Preferences.showShadow }, { Preferences.showShadow = $0 })).labelsHidden().toggleStyle(.switch)
                }
            }
            Card(title: "Motion") {
                Row("Follow behavior") {
                    Picker("Follow behavior", selection: model.binding({ Preferences.pointerMotion }, { Preferences.pointerMotion = $0 })) {
                        ForEach(PointerMotion.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented).frame(width: 200)
                }
                Row(Preferences.pointerMotion == .original ? "Original motion" : "Responsive motion",
                    detail: Preferences.pointerMotion == .original
                        ? "The original, looser grip swing."
                        : "The grip follows small movements more closely and catches up to quick flicks.") {
                    EmptyView()
                }
            }
            Card(title: "Toolbar") {
                Row("Show the toolbar", detail: "Reveal it when the pointer starts or when you move near it.") {
                    Toggle("Show toolbar", isOn: model.binding({ Preferences.showToolbar }, { Preferences.showToolbar = $0 })).labelsHidden().toggleStyle(.switch)
                }
                Row("Position", detail: "Drag its handle to move it. Right-click the handle to reset.") {
                    PillButton(title: "Reset Position") { Preferences.toolbarPosition = nil }
                }
            }
        }
    }
}

struct DrawingPage: View {
    @ObservedObject var model: SettingsModel
    private let fadeChoices: [(String, Double)] = [("After 3 seconds", 3), ("After 6 seconds", 6), ("After 10 seconds", 10), ("Keep until cleared", 0)]
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            Card(title: "Tools") {
                Row("Selected tool", detail: "Use the tool row in Draw mode, or its keyboard shortcut.") {
                    Picker("Drawing tool", selection: model.binding({ Preferences.drawingTool }, { Preferences.drawingTool = $0 })) {
                        ForEach(DrawingTool.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }.labelsHidden().fixedSize()
                }
                Row("Number markers", detail: "Choose Number or Control-click in Draw. Drag a marker to move it; click it to remove it.") { EmptyView() }
                Row("Text labels", detail: "Click where the label belongs. Return adds text; Escape cancels.") { EmptyView() }
            }
            Card(title: "Stroke") {
                Row("Line width") {
                    HStack(spacing: Space.sm) {
                        Slider(value: model.binding({ Double(Preferences.strokeWidth) }, { Preferences.strokeWidth = CGFloat($0) }), in: 2...20, step: 1)
                            .frame(width: 160).accessibilityLabel("Line width")
                        Text("\(Int(Preferences.strokeWidth)) pt").monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                }
                Row("Opacity") {
                    HStack(spacing: Space.sm) {
                        Slider(value: model.binding({ Double(Preferences.inkOpacity) }, { Preferences.inkOpacity = CGFloat($0) }), in: 0.1...1, step: 0.05)
                            .frame(width: 160).accessibilityLabel("Ink opacity")
                        Text("\(Int((Preferences.inkOpacity * 100).rounded()))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                }
                Row("Smoothing", detail: "The end of a line stays at the pointer.") {
                    Picker("Line smoothing", selection: model.binding({ Preferences.strokeSmoothing }, { Preferences.strokeSmoothing = $0 })) {
                        ForEach(StrokeSmoothing.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().fixedSize()
                }
            }
            Card(title: "Ink") {
                Row("Color") {
                    HStack(spacing: Space.xs) {
                        ForEach(InkChoice.allCases, id: \.self) { choice in
                            InkSwatch(choice: choice, selected: Preferences.inkChoice == choice) { Preferences.inkChoice = choice }
                        }
                    }
                }
                Row("Lines fade") {
                    Picker("Lines fade", selection: model.binding({ Preferences.fadeSeconds }, { Preferences.fadeSeconds = $0 })) {
                        ForEach(fadeChoices, id: \.1) { Text($0.0).tag($0.1) }
                    }.labelsHidden().fixedSize()
                }
            }
        }
    }
}
