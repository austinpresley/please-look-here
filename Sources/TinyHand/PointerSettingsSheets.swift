import AppKit
import SwiftUI

struct NewHandSheet: View {
    @ObservedObject var model: SettingsModel
    @State private var dropping = false
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("New Hand").font(.system(size: 20, weight: .semibold))
                .gridProbe("newHand.title", area: "pointer.newHand")
            SettingsSubtitle("Add a transparent PNG showing the back of the hand.")
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    if let draft = model.draft {
                        HStack(spacing: Space.lg) {
                            Image(nsImage: NSImage(cgImage: draft.image, size: .zero)).resizable().scaledToFit().frame(width: 112, height: 144)
                                .background(TransparencyPreview()).clipShape(RoundedRectangle(cornerRadius: Space.sm))
                            VStack(alignment: .leading, spacing: Space.sm) {
                                Label("Image ready", systemImage: "checkmark.circle")
                                SettingsSubtitle("Check the transparent edges and hand orientation. Use the back of the hand, rather than a palm.")
                                Button("Choose Another Image…") { model.chooseHandFile() }
                            }
                        }
                    } else {
                        Button { model.chooseHandFile() } label: {
                            VStack(spacing: Space.sm) {
                                Image(systemName: "square.and.arrow.down").font(.title2)
                                Text("Drop a PNG here, or choose an image…")
                            }.frame(maxWidth: .infinity).frame(height: 96)
                                .background(RoundedRectangle(cornerRadius: Space.sm).fill(Color.primary.opacity(dropping ? 0.10 : 0.04)))
                        }.buttonStyle(.plain)
                    }
                    if let error = model.draftError { Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red) }
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("Need an image? Describe your hand").font(.system(size: 12, weight: .semibold))
                        TextField("e.g. knitted wool in mustard yellow", text: $model.handIdea).textFieldStyle(.roundedBorder)
                        HStack(spacing: Space.sm) {
                            Button("Copy Prompt & Open ChatGPT") { model.openChatGPT() }
                            Button(model.promptCopied ? "Copied" : "Copy Prompt") { model.copyPrompt() }
                        }
                        SettingsSubtitle("Download a transparent PNG, then choose it above. The app validates it before saving.")
                    }
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("Name").font(.system(size: 12, weight: .semibold))
                        TextField("My hand", text: Binding(get: { model.handName }, set: { model.handName = String($0.prefix(16)) })).textFieldStyle(.roundedBorder)
                    }
                    SettingsSubtitle("Add Hand saves it and makes it your pointer.")
                }
                .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url { DispatchQueue.main.async { model.loadDraft(url) } }
                    }
                    return true
                }
            }
            HStack(spacing: Space.md) {
                Spacer()
                Button("Cancel") { model.makingHand = false }.keyboardShortcut(.cancelAction)
                Button("Add Hand") { model.saveDraft() }.keyboardShortcut(.defaultAction)
                    .disabled(model.draft == nil || model.handName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Space.xxl).frame(width: 640, height: 560)
        .gridArea("pointer.newHand", inset: Space.xxl)
    }
}
