import SwiftUI

struct MagnificationSettings: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        Card(title: "Magnification") {
            Row("Zoom") {
                HStack(spacing: Space.sm) {
                    Slider(value: model.binding({ Preferences.magnifierZoom }, { Preferences.magnifierZoom = $0 }), in: 1.5...6, step: 0.5)
                        .frame(width: 144).accessibilityLabel("Magnification zoom")
                    Text(String(format: "%.1f×", Preferences.magnifierZoom)).monospacedDigit().frame(width: 48, alignment: .trailing)
                }
            }
            Row("Lens size") {
                HStack(spacing: Space.sm) {
                    Slider(value: model.binding({ Preferences.magnifierDiameter }, { Preferences.magnifierDiameter = $0 }), in: 160...480, step: 16)
                        .frame(width: 144).accessibilityLabel("Magnification lens size")
                    Text("\(Int(Preferences.magnifierDiameter)) pt").monospacedDigit().frame(width: 48, alignment: .trailing)
                }
            }.help("The lens stays on the current display and marks the cursor position.")
        }.help("Toggle magnification from the toolbar or menu bar. Requires Screen Recording access.")
    }
}
