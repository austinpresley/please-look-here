import AppKit
import ApplicationServices
import SwiftUI

struct GeneralPage: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            Card(title: "Using the pointer") {
                Row("Interact", detail: "On: use apps normally. Off: draw on screen.") {
                    Toggle("Interact", isOn: model.binding({ Preferences.pointerMode.isInteractive }, { enabled in
                        let mode: PointerMode = enabled ? .point : .draw
                        if model.applyMode?(mode) == false {
                            model.generalMessage = "Allow Accessibility to draw. Interact stays on."
                        } else {
                            if model.applyMode == nil { Preferences.pointerMode = mode }
                            model.generalMessage = nil
                        }
                    })).labelsHidden().toggleStyle(.switch)
                    .help("Let clicks reach the app underneath. Turn off to draw on screen.")
                }
                Row("Keep the hand visible while interacting", detail: "When off, hide it during clicks and drags, then show it on release.") {
                    Toggle("Keep the hand visible while interacting", isOn: model.binding({ Preferences.interactKeepsHand }, { Preferences.interactKeepsHand = $0 })).labelsHidden().toggleStyle(.switch)
                }
            }
            if let message = model.generalMessage { Text(message).font(.callout).foregroundStyle(.secondary) }
            StreamDeckSettings()
            Card(title: "Permissions") {
                Row("Drawing", detail: AXIsProcessTrusted() ? "Accessibility is allowed." : "Interact works without this permission.") {
                    PillButton(title: AXIsProcessTrusted() ? "Review…" : "Allow Drawing…") {
                        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
                        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
                    }
                }
                Row("Screenshots and magnification", detail: ScreenCapture.hasPermission ? "Screen Recording is allowed." : "Requested when you first take a screenshot or turn on magnification.") {
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
                Row("Open Look Here Please when you log in") {
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
            Text("Shortcuts start unassigned. Click a row’s shortcut control to record keys, or Clear to remove them. Tool keys work with Interact off and pause while you type or edit Settings.")
                .font(.callout).foregroundStyle(.secondary)
            Card(title: "Quick controls at the cursor") {
                Row("Hold to open", detail: "Only while the pointer is on. Starts unassigned.") {
                    Picker("Radial menu modifier", selection: model.binding({ Preferences.radialTrigger?.rawValue ?? "" }, { Preferences.radialTrigger = RadialTrigger(rawValue: $0) })) {
                        Text("Unassigned").tag("")
                        ForEach(RadialTrigger.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                    }.labelsHidden().pickerStyle(.menu).frame(width: 160)
                    Button("Clear") { Preferences.radialTrigger = nil }.disabled(Preferences.radialTrigger == nil)
                        .accessibilityLabel("Clear radial menu modifier")
                        .help("Remove the radial menu modifier. Leave it Unassigned.")
                }
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("Hold the modifier alone. Move through Pointer, Color or Tools to the outer choices, then release to select. Move inward to go back. Release at the center, press Escape or click outside to cancel. Next and Previous show more choices; move inward slightly before choosing again.")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("At a display edge, enter the shifted center first. During a drag, Settings, text entry or capture, the menu stays closed. Other keys close it and keep their usual shortcuts. Requires Accessibility permission.")
                        .font(.callout).foregroundStyle(.secondary)
                }.padding(Space.lg)
            }
            HandGestureShortcutSettings(model: model)
            Card(title: "Pointer and drawing") {
                Row("Turn pointer on or off") {
                    ShortcutField(shortcut: Preferences.toggleShortcut, model: model, command: "toggle", label: "Turn pointer on or off") { model.applyToggleShortcut?($0) ?? false }
                }
                Row("Clear Drawing") {
                    ShortcutField(shortcut: Preferences.clearShortcut, model: model, command: "clear", label: "Clear Drawing") { model.applyClearShortcut?($0) ?? false }
                }
                ForEach(PresentationAction.allCases.filter { !$0.drawOnly && $0.gesture == nil }, id: \.self) { action in shortcutRow(action) }
            }
            Card(title: "Drawing with Interact off") {
                ForEach(PresentationAction.allCases.filter(\.drawOnly), id: \.self) { action in shortcutRow(action) }
                Text("Standard editing shortcuts stay available in app text fields. Command-comma opens Settings while an app window is focused.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if let error = model.shortcutError { Text(error).font(.callout).foregroundStyle(.red) }
        }
    }
    private func shortcutRow(_ action: PresentationAction) -> some View {
        Row(action.title) {
            ShortcutField(shortcut: Preferences.shortcut(for: action), model: model, command: action.rawValue, label: action.title, allowsPlainKeys: action.tool != nil) {
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
                Row("Size", detail: "Relative to the display height. Also sets Spotlight's circle size and Presentation pointer's thickness.") {
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
                Row("Shadow style", detail: Preferences.shadowStyle == .contact
                    ? "Dark at the fingertip, softer as the hand lifts away."
                    : "The original soft shadow under the hand.") {
                    Picker("Shadow style", selection: model.binding({ Preferences.shadowStyle }, { Preferences.shadowStyle = $0 })) {
                        ForEach(PointerShadowStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).frame(width: 144)
                    .disabled(!Preferences.showShadow)
                    .help("Choose the hand's shadow. The laser keeps its own glow.")
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
                Row("Tap swing", detail: "Optional wind-up and strike. Off keeps the current tap. Drags touch down immediately; Reduce Motion turns the swing off.") {
                    HStack(spacing: Space.sm) {
                        Slider(value: model.binding({ Preferences.tapSwing }, { Preferences.tapSwing = $0 }), in: 0...2, step: 0.1)
                            .frame(width: 144).accessibilityLabel("Tap swing")
                        Text(Preferences.tapSwing < 0.01 ? "Off" : String(format: "%.1f×", Preferences.tapSwing))
                            .monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                }
            }
            MagnificationSettings(model: model)
            Card(title: "Toolbar") {
                Row("Show toolbar", detail: "Reveal at pointer startup or nearby. Hide when you move away. Off keeps it hidden.") {
                    Toggle("Show toolbar", isOn: model.binding({ Preferences.showToolbar }, { Preferences.showToolbar = $0 })).labelsHidden().toggleStyle(.switch)
                        .help("Show for 3 seconds when the pointer starts or this setting turns on, then while the cursor is nearby. Off keeps the floating toolbar hidden. Controls remain in the menu bar.")
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
    private let fadeChoices: [(String, Double)] = [("3 seconds", 3), ("6 seconds", 6), ("10 seconds", 10)]
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            Card(title: "Tools") {
                Row("Selected tool", detail: "With Interact off, use the tool row or its keyboard shortcut.") {
                    Picker("Drawing tool", selection: model.binding({ Preferences.drawingTool }, { Preferences.drawingTool = $0 })) {
                        ForEach(DrawingTool.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }.labelsHidden().fixedSize()
                }
                Row("Number markers", detail: "With Interact off, choose Number or Control-click. Drag a marker to move it; click it to remove it.") { EmptyView() }
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
                Row("Fading", detail: Preferences.inkFadeStyle == .trail
                    ? "The start of a pen stroke erases as you draw. Other annotations fade as a whole."
                    : "Choose how long annotations stay on screen.") {
                    Picker("Ink fading", selection: model.binding({ Preferences.inkFadeStyle }, { Preferences.inkFadeStyle = $0 })) {
                        ForEach(InkFadeStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().fixedSize()
                }
                if Preferences.inkFadeStyle != .permanent {
                    Row(Preferences.inkFadeStyle == .trail ? "Other annotations fade after" : "Fade after") {
                        Picker("Fade delay", selection: model.binding({ max(0.5, Preferences.fadeSeconds) }, { Preferences.fadeSeconds = $0 })) {
                            ForEach(fadeChoices, id: \.1) { Text($0.0).tag($0.1) }
                        }.labelsHidden().fixedSize()
                    }
                }
                if Preferences.inkFadeStyle == .trail {
                    Row("Trail delay") {
                        HStack(spacing: Space.sm) {
                            Slider(value: model.binding({ Preferences.trailDelay }, { Preferences.trailDelay = $0 }), in: 0.2...3, step: 0.2)
                                .frame(width: 144).accessibilityLabel("Trail delay")
                            Text(String(format: "%.1f s", Preferences.trailDelay)).monospacedDigit().frame(width: 56, alignment: .trailing)
                        }
                    }
                    Row("Trail speed") {
                        HStack(spacing: Space.sm) {
                            Slider(value: model.binding({ Preferences.trailSpeed }, { Preferences.trailSpeed = $0 }), in: 40...600, step: 20)
                                .frame(width: 144).accessibilityLabel("Trail speed")
                            Text("\(Int(Preferences.trailSpeed)) pt/s").monospacedDigit().frame(width: 56, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}
