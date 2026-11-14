import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

struct MakeHandPage: View {
    @ObservedObject var model: SettingsModel
    @State private var dropping = false

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Step(number: 1, title: "Describe it", detail: "What should your hand look like?") {
                PlainField(placeholder: "e.g. knitted wool in mustard yellow", text: $model.handIdea)
                    .frame(maxWidth: 420)
            }
            Step(number: 2, title: "Make the image", detail: "Open it in ChatGPT, or copy the prompt for another image tool. Download the result as a PNG with a transparent background.") {
                HStack(spacing: 8) {
                    PrimaryButton(title: "Open in ChatGPT", symbol: "arrow.up.right") { model.openChatGPT() }
                    PrimaryButton(title: model.promptCopied ? "Copied" : "Copy prompt", symbol: model.promptCopied ? "checkmark" : "doc.on.doc", primary: false) {
                        model.copyPrompt()
                    }
                }
            }
            Step(number: 3, title: "Add it", detail: nil) {
                if let draft = model.draft {
                    preview(draft)
                } else {
                    dropZone
                }
            }
        }
    }

    private var dropZone: some View {
        Button {
            model.chooseHandFile()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: model.draftError == nil ? "square.and.arrow.down" : "exclamationmark.triangle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(model.draftError == nil ? .secondary : .orange)
                Text(model.draftError ?? "Drop the PNG here, or click to choose it")
                    .font(.system(size: 12))
                    .foregroundColor(model.draftError == nil ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if model.draftError != nil {
                    Text("Try again with another image")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(dropping ? 0.07 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(dropping ? Color.accentColor : Color.primary.opacity(0.14), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
            guard let provider = providers.first else {
                return false
            }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else {
                    return
                }
                DispatchQueue.main.async { model.loadDraft(url) }
            }
            return true
        }
    }

    private func preview(_ draft: SettingsModel.HandDraft) -> some View {
        HStack(alignment: .center, spacing: 22) {
            Image(nsImage: NSImage(cgImage: draft.image.cropping(to: CGRect(x: 112, y: 90, width: 800, height: 1000)) ?? draft.image, size: NSSize(width: 144, height: 180)))
                .resizable()
                .interpolation(.high)
                .frame(width: 144, height: 180)
                .padding(.vertical, 10)
                .frame(width: 170)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.91, green: 0.81, blue: 0.71))
                )
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    PlainField(placeholder: "My hand", text: Binding(get: { model.handName }, set: { model.handName = String($0.prefix(16)) }))
                        .frame(width: 220)
                }
                Text("It should show the back of the hand, like the ones in Look Here Please. If you see the palm, try another image.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 300, alignment: .leading)
                HStack(spacing: 10) {
                    PrimaryButton(title: "Add hand", symbol: nil) { model.saveDraft() }
                    TextButton(title: "Use another image") { model.chooseHandFile() }
                }
            }
        }
    }
}


struct Step<Content: View>: View {
    let number: Int
    let title: String
    let detail: String?
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.primary.opacity(0.75)))
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    if let detail = detail {
                        Text(detail).font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                content
            }
        }
    }
}


struct PlainField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .modifier(NoFocusEffect())
    }
}


struct NoFocusEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled()
        } else {
            content
        }
    }
}


struct PrimaryButton: View {
    let title: String
    let symbol: String?
    var primary = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol = symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 14, height: 14)
                }
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(primary ? .white : .primary)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(Capsule().fill(primary
                ? Color.accentColor.opacity(hovering ? 0.88 : 1)
                : Color.primary.opacity(hovering ? 0.14 : 0.09)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering = $0 }
    }
}
