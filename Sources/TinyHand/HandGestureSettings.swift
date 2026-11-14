import AppKit
import SwiftUI

struct HandGestureSettings: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        let style = PointerStyle.saved
        Card(title: "Hand gestures") {
            if style.assetName == nil {
                Row("Choose a hand", detail: "Gestures work with hands. Laser dot, Spotlight and Presentation pointer keep their own appearance.") { EmptyView() }
            } else {
                Row("For \(style.title)", detail: "OK and Shaka are starter poses. Import transparent artwork to match this hand. The pointer selection and its stick stay the same.") {
                    Button("Assign Shortcuts") { model.section = .shortcuts }
                }
                ForEach(HandGestureSlot.allCases, id: \.self) { slot in
                    HStack(spacing: Space.md) {
                        if let base = style.assetName.flatMap(HandAsset.load), let image = HandGestureCatalog.image(slot, style: style) {
                            Image(nsImage: base.replacingImage(image).thumbnail)
                                .resizable().scaledToFit().frame(width: 64, height: 64)
                                .background(TransparencyPreview().clipShape(RoundedRectangle(cornerRadius: 8)))
                                .accessibilityLabel("\(slot.title) artwork")
                        } else { Image(systemName: "photo.badge.exclamationmark").frame(width: 64, height: 64).accessibilityLabel("Gesture image unavailable") }
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text(slot.title).font(.headline)
                            Text(HandGestureCatalog.hasCustom(slot, style: style) ? "Custom artwork" : slot.stockTitle)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: Space.sm)
                        VStack(alignment: .trailing, spacing: Space.sm) {
                            Button("Import Artwork…") { model.chooseGestureFile(slot, for: style) }
                                .accessibilityLabel("Import \(slot.title) artwork for \(style.title)")
                            if HandGestureCatalog.hasCustom(slot, style: style) {
                                Button("Restore Starter") { model.restoreGesture(slot, for: style) }
                                    .accessibilityLabel("Restore \(slot.title) starter artwork")
                            }
                        }
                    }.padding(Space.lg)
                }
                if let message = model.gestureMessage { Text(message).font(.callout).foregroundStyle(.secondary).padding(Space.lg) }
            }
        }
    }
}

struct HandGestureShortcutSettings: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        Card(title: "Hand gestures") {
            Text("Hold an assigned shortcut to show a pose. Release to restore the hand. The menu bar can show either pose for two seconds. Artwork is set per hand in Pointers.")
                .font(.callout).foregroundStyle(.secondary).padding(Space.lg)
            ForEach(HandGestureSlot.allCases, id: \.self) { slot in
                Row("Hold \(slot.title)", detail: "Starts unassigned. Works while an available hand is on.") {
                    ShortcutField(shortcut: Preferences.shortcut(for: slot.action), model: model, label: slot.action.title) {
                        model.applyPresentationShortcut?(slot.action, $0) ?? false
                    }
                }
            }
        }
    }
}
