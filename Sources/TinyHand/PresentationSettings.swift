import SwiftUI

struct DrawingPage: View {
    @ObservedObject var model: SettingsModel
    private let fadeChoices: [Double] = [1, 3, 5, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            DrawingPreview(configuration: .current)
            Card(title: "Ink") {
                Row("Color") {
                    HStack(spacing: Space.xs) {
                        ForEach(InkChoice.allCases, id: \.self) { choice in
                            InkSwatch(choice: choice, selected: Preferences.inkChoice == choice) { Preferences.inkChoice = choice }
                        }
                    }
                }
                Row("Line width") {
                    HStack(spacing: Space.sm) {
                        ForEach([3, 6, 10, 16], id: \.self) { width in
                            Button { Preferences.strokeWidth = CGFloat(width); model.refresh() } label: {
                                Capsule().fill(Color.primary).frame(width: 20, height: CGFloat(width) / 2)
                                    .frame(width: 28, height: 20)
                                    .background(RoundedRectangle(cornerRadius: Space.xs).fill(Preferences.strokeWidth == CGFloat(width) ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.04)))
                                    .overlay(RoundedRectangle(cornerRadius: Space.xs).strokeBorder(Preferences.strokeWidth == CGFloat(width) ? Color.accentColor : .clear))
                            }.buttonStyle(.plain).help("\(width) pt").accessibilityLabel("Line width \(width) points")
                                .accessibilityAddTraits(Preferences.strokeWidth == CGFloat(width) ? .isSelected : [])
                        }
                        Slider(value: model.binding({ Double(Preferences.strokeWidth) }, { Preferences.strokeWidth = CGFloat($0) }), in: 2...20, step: 1)
                            .frame(width: 112).accessibilityLabel("Line width, 2 to 20 points")
                        Text("\(Int(Preferences.strokeWidth)) pt").monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                }
                Row("Opacity") {
                    HStack(spacing: Space.sm) {
                        Slider(value: model.binding({ Double(Preferences.inkOpacity) }, { Preferences.inkOpacity = CGFloat($0) }), in: 0.1...1, step: 0.05)
                            .frame(width: 144).accessibilityLabel("Ink opacity")
                        Text("\(Int((Preferences.inkOpacity * 100).rounded()))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                }
            }
            Card(title: "Behavior") {
                HStack(spacing: Space.sm) {
                    ForEach([InkFadeStyle.permanent, .wholeLine, .trail], id: \.self) { style in
                        Button { Preferences.inkFadeStyle = style; model.refresh() } label: {
                            VStack(spacing: Space.xs) {
                                BehaviorStroke().trim(from: style == .trail ? 0.4 : 0, to: 1)
                                    .stroke(LinearGradient(colors: [Color.accentColor.opacity(style == .permanent ? 1 : 0.18), .accentColor], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 72, height: 20)
                                    .opacity(style == .wholeLine ? 0.5 : 1)
                                Text(style == .permanent ? "Keep" : style == .wholeLine ? "Fade" : "Trail").font(.system(size: 12))
                            }
                            .frame(maxWidth: .infinity).padding(Space.sm)
                            .background(RoundedRectangle(cornerRadius: Space.sm).fill(Preferences.inkFadeStyle == style ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.025)))
                            .overlay(RoundedRectangle(cornerRadius: Space.sm).strokeBorder(Preferences.inkFadeStyle == style ? Color.accentColor : .clear, lineWidth: 2))
                        }.buttonStyle(.plain).accessibilityLabel(style == .permanent ? "Keep ink" : style == .wholeLine ? "Fade whole marks" : "Trail erases the start of pen lines")
                            .accessibilityAddTraits(Preferences.inkFadeStyle == style ? .isSelected : [])
                    }
                }.padding(Space.sm)
                if Preferences.inkFadeStyle != .permanent {
                    Row(Preferences.inkFadeStyle == .trail ? "Other marks fade after" : "Fade after") {
                        Picker("Fade delay", selection: model.binding({ max(0.5, Preferences.fadeSeconds) }, { Preferences.fadeSeconds = $0 })) {
                            ForEach(fadeChoices, id: \.self) { Text("\(Int($0)) seconds").tag($0) }
                            if !fadeChoices.contains(max(0.5, Preferences.fadeSeconds)) {
                                Text(String(format: "%.1f seconds", max(0.5, Preferences.fadeSeconds))).tag(max(0.5, Preferences.fadeSeconds))
                            }
                        }.labelsHidden().frame(width: 144)
                    }
                }
            }
            SettingsDisclosure(title: "Smoothing and trail timing", summary: Preferences.strokeSmoothing.title, isExpanded: $model.drawingAdvanced) {
                Row("Smoothing") {
                    Picker("Line smoothing", selection: model.binding({ Preferences.strokeSmoothing }, { Preferences.strokeSmoothing = $0 })) {
                        ForEach(StrokeSmoothing.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 144)
                }
                Group {
                    Row("Trail tail delay") {
                        HStack(spacing: Space.sm) {
                            Slider(value: model.binding({ Preferences.trailDelay }, { Preferences.trailDelay = $0 }), in: 0.2...3, step: 0.2)
                                .frame(width: 144).accessibilityLabel("Trail delay")
                            Text(String(format: "%.1f s", Preferences.trailDelay)).monospacedDigit().frame(width: 56, alignment: .trailing)
                        }
                    }
                    Row("Trail tail speed") {
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

/// Static stroke pictures explain lifetime choices; practice uses Ink's renderer.
private struct BehaviorStroke: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control1: CGPoint(x: rect.width * 0.36, y: rect.minY - 8), control2: CGPoint(x: rect.width * 0.64, y: rect.maxY + 8))
        }
    }
}
