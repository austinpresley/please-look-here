import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, shortcuts, drawing, pointers, appearance, sound, presets, about

    var id: String { rawValue }
    static let sidebarCases: [Self] = [.pointers, .drawing, .shortcuts, .presets, .general]

    var canonical: Self {
        switch self { case .appearance, .sound: return .pointers; case .about: return .general; default: return self }
    }

    var title: String {
        switch self {
        case .general: return "General"
        case .shortcuts: return "Shortcuts"
        case .pointers: return "Pointers"
        case .appearance: return "Pointer defaults"
        case .drawing: return "Tools"
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
        .frame(minWidth: model.section == .pointers ? 1040 : 784, minHeight: 440)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: Binding<SettingsSection?>(
                get: { model.section },
                set: { if let section = $0 {
                    model.cancelShortcutNavigation()
                    model.section = section
                } }
            )) {
                ForEach(SettingsSection.sidebarCases) { section in
                    HStack(spacing: Space.sm) {
                        Image(systemName: section.symbol).frame(width: 16, height: 16).foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(section.title).font(.system(size: 12)).lineLimit(1).layoutPriority(1)
                    }
                    .listRowInsets(EdgeInsets(top: Space.xs, leading: Space.xs, bottom: Space.xs, trailing: Space.xs))
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
                Text("Look Here Please").font(.system(size: 11, weight: .semibold)).lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .padding(.top, 52)
        .padding(.horizontal, 12)
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .background(VisualEffect(material: .sidebar))
    }

    private var page: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                Text(model.section.title)
                    .font(.system(size: 22, weight: .bold))
                    .frame(height: 28, alignment: .leading)
                    .padding(.top, 4)
                    .gridProbe("page.title", area: "page")
                    .id("settings-top")
                content
                    .gridProbe("page.content", area: "page")
                    .id("settings-bottom")
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
        .onChange(of: model.shortcutFocusRequest) { _ in
            model.onShortcutNavigationLayout?()
        }
        .onChange(of: model.scrollToBottom) { bottom in
            proxy.scrollTo(bottom ? "settings-bottom" : "settings-top", anchor: bottom ? .bottom : .top)
        }
        .onChange(of: model.revealDefaultSound) { value in
            if value { proxy.scrollTo("default-sound", anchor: .top); model.revealDefaultSound = false }
        }
        .sheet(isPresented: Binding(get: { model.makingHand }, set: { presented in
            if !presented { model.makingHand = false }
        })) {
            NewHandSheet(model: model)
        }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.section {
        case .general: GeneralPage(model: model)
        case .shortcuts: ShortcutsPage(model: model)
        case .pointers: PointersPage(model: model)
        case .appearance: PointersPage(model: model)
        case .drawing: ToolsSettingsPage(model: model)
        case .sound: PointersPage(model: model)
        case .presets: PresetsPage(settings: model)
        case .about: GeneralPage(model: model)
        }
    }
}

private struct SettingsContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
