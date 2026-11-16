import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, shortcuts, drawing, pointers, appearance, sound, presets, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .shortcuts: return "Shortcuts"
        case .pointers: return "Pointers"
        case .appearance: return "Appearance"
        case .drawing: return "Drawing"
        case .sound: return "Sound"
        case .presets: return "Presets"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .shortcuts: return "keyboard"
        case .pointers: return "hand.point.up.left.fill"
        case .appearance: return "sparkles"
        case .drawing: return "pencil.tip"
        case .sound: return "speaker.wave.2.fill"
        case .presets: return "square.stack"
        case .about: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: return Color(white: 0.55)
        case .shortcuts: return Color(white: 0.55)
        case .pointers: return Color(red: 0.55, green: 0.42, blue: 0.95)
        case .appearance: return Color(red: 0.95, green: 0.45, blue: 0.6)
        case .drawing: return Color(red: 0.96, green: 0.58, blue: 0.2)
        case .sound: return Color(red: 0.2, green: 0.55, blue: 0.98)
        case .presets: return Color(white: 0.55)
        case .about: return Color(white: 0.45)
        }
    }
}


struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            page
        }
        .ignoresSafeArea()
        .frame(minWidth: 784, minHeight: 440)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: Binding<SettingsSection?>(
                get: { model.section },
                set: { if let section = $0 { model.section = section } }
            )) {
                ForEach(SettingsSection.allCases) { section in
                    HStack(spacing: Space.sm) {
                        IconTile(symbol: section.symbol, tint: section.tint)
                            .accessibilityHidden(true)
                        Text(section.title)
                    }
                    .tag(section)
                    .accessibilityLabel(section.title)
                    .accessibilityValue(model.section == section ? "Selected" : "")
                    .accessibilityAddTraits(model.section == section ? .isSelected : [])
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .accessibilityLabel("Settings sections")
            Spacer()
            HStack(spacing: 8) {
                if let icon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: icon).resizable().frame(width: 24, height: 24)
                }
                Text("Look Here Please").font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .padding(.top, 52)
        .padding(.horizontal, 12)
        .frame(width: 208)
        .frame(maxHeight: .infinity)
        .background(VisualEffect(material: .sidebar))
    }

    private var page: some View {
        ScrollViewReader { scroll in
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                if model.section == .pointers && model.makingHand {
                    Button {
                        model.makingHand = false
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                            Text("Pointers").font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .padding(.bottom, -12)
                }
                Text(model.section == .pointers && model.makingHand ? "Make your own hand" : model.section.title)
                    .font(.system(size: 22, weight: .bold))
                    .frame(height: 28, alignment: .leading)
                    .padding(.top, 4)
                    .gridProbe("page.title", area: "page")
                content
                    .gridProbe("page.content", area: "page")
            }
            .padding(.horizontal, Space.margin)
            .padding(.top, 48)
            .padding(.bottom, Space.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GeometryReader { proxy in Color.clear.preference(key: SettingsContentHeight.self, value: proxy.size.height) })
            .onPreferenceChange(SettingsContentHeight.self) { model.onContentHeightChanged?($0) }
            .gridArea("page")
            .id(model.section)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: model.shortcutFocusRequest) { request in
            guard model.section == .shortcuts, let request else { return }
            scroll.scrollTo(request.target.id, anchor: .center)
        }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.section {
        case .general: GeneralPage(model: model)
        case .shortcuts: ShortcutsPage(model: model)
        case .pointers:
            if model.makingHand {
                MakeHandPage(model: model)
            } else {
                PointersPage(model: model)
            }
        case .appearance: AppearancePage(model: model)
        case .drawing: DrawingPage(model: model)
        case .sound: SoundPage(model: model)
        case .presets: PresetsPage()
        case .about: AboutPage(model: model)
        }
    }
}

private struct SettingsContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
