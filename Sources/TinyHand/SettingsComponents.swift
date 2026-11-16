import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

struct IconTile: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .top, endPoint: .bottom))
            .frame(width: 24, height: 24)
            .overlay(Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundColor(.white))
    }
}


struct Card<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                    .frame(height: 16, alignment: .leading)
                    .gridProbe("card.\(title).title", area: "card.\(title)", edge: nil)
            }
            VStack(spacing: 0) {
                _VariadicView.Tree(Separated()) {
                    content
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )
            .gridProbe("card.\(title ?? "content").body", area: "card.\(title ?? "content")", edge: nil)
        }
        .gridArea("card.\(title ?? "content")", inset: 0)
    }
}


struct Separated: _VariadicView_MultiViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        ForEach(children) { child in
            child
            if child.id != last {
                Rectangle()
                    .fill(Color.primary.opacity(0.07))
                    .frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }
}


struct Row<Trailing: View>: View {
    let title: String
    let detail: String?
    @ViewBuilder let trailing: Trailing

    init(_ title: String, detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let detail = detail {
                    Text(detail).font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
    }
}


struct LinkRow: View {
    let title: String
    let detail: String
    let url: String
    @State private var hovering = false

    var body: some View {
        Button {
            if let u = URL(string: url) {
                NSWorkspace.shared.open(u)
            }
        } label: {
            HStack {
                Text(title).font(.system(size: 13)).foregroundColor(.primary)
                Spacer()
                Text(detail).font(.system(size: 12)).foregroundColor(.secondary)
                Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Color.primary.opacity(hovering ? 0.04 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
        .onHover { hovering = $0 }
    }
}


struct TextButton: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(hovering ? .primary : .secondary)
        }
        .buttonStyle(.borderless)
        .onHover { hovering = $0 }
    }
}


struct PillButton: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
        .padding(.vertical, 8)
                .background(Capsule().fill(Color.primary.opacity(hovering ? 0.14 : 0.09)))
        }
        .buttonStyle(.borderless)
        .onHover { hovering = $0 }
    }
}


struct ShortcutField: View {
    let shortcut: Shortcut?
    @ObservedObject var model: SettingsModel
    var command: String?
    var label = "Shortcut"
    var allowsPlainKeys = false
    let apply: (Shortcut?) -> Bool
    @State private var assignmentError: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: Space.xs) {
            HStack(spacing: Space.sm) {
                ShortcutRecordingField(shortcut: shortcut, model: model, command: command, label: label,
                                       allowsPlainKeys: allowsPlainKeys) { value in
                    let accepted = apply(value)
                    assignmentError = accepted ? nil : model.shortcutError
                    return accepted
                }
                .frame(width: 132, height: 32)
                Button("Clear") {
                    if apply(nil) {
                        model.shortcutError = nil
                        assignmentError = nil
                    }
                }
                .disabled(shortcut == nil)
                .help("Clear the shortcut for \(label)")
                .accessibilityLabel("Clear \(label) shortcut")
            }
            if let error = assignmentError ?? command.flatMap({ model.shortcutConflicts[$0] }) {
                Text(error).font(.callout).foregroundStyle(.red)
                    .frame(width: 224, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ShortcutRecordingField: NSViewRepresentable {
    let shortcut: Shortcut?
    let model: SettingsModel
    var command: String?
    var label = "Shortcut"
    var allowsPlainKeys = false
    let apply: (Shortcut?) -> Bool

    func makeNSView(context: Context) -> ShortcutRecorder {
        let r = ShortcutRecorder(shortcut: shortcut, command: command)
        r.setAccessibilityLabel(label)
        r.allowsPlainKeys = allowsPlainKeys
        r.onRecording = { model.onRecording?($0) }
        r.onChange = { s in
            let ok = apply(s)
            if ok { model.shortcutError = nil }
            return ok
        }
        return r
    }

    func updateNSView(_ nsView: ShortcutRecorder, context: Context) {
        nsView.setNavigationCommand(command)
        nsView.show(shortcut)
    }
}


struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private let blankIcon = NSImage(size: NSSize(width: 64, height: 64))

func pointerIcon(_ style: PointerStyle) -> NSImage? {
    guard let name = style.assetName else {
        return Toolbar.icon(for: style)
    }
    return HandAsset.cachedThumbnail(name) ?? blankIcon
}
