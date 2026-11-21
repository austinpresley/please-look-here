import AppKit
import SwiftUI

/// Product glyphs where SF Symbols has no matching concept. Template images
/// inherit the host's foreground color in AppKit and SwiftUI, in either theme.
enum UsabilityGlyph {
    case wheel, library
    var image: NSImage {
        let image = NSImage(size: CGSize(width: 24, height: 24), flipped: false) { rect in
            NSColor.labelColor.setStroke(); NSColor.labelColor.setFill()
            if self == .wheel {
                let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2)); ring.lineWidth = 1.5; ring.stroke()
                let hub = NSBezierPath(ovalIn: rect.insetBy(dx: 8, dy: 8)); hub.lineWidth = 1.5; hub.stroke()
                for spoke in 0..<6 {
                    let angle = CGFloat(spoke) * .pi / 3 + .pi / 2
                    let path = NSBezierPath()
                    path.move(to: CGPoint(x: 12 + cos(angle) * 4, y: 12 + sin(angle) * 4))
                    path.line(to: CGPoint(x: 12 + cos(angle) * 10, y: 12 + sin(angle) * 10))
                    path.lineWidth = 1.5; path.stroke()
                }
            } else {
                for box in [CGRect(x: 2, y: 14, width: 7, height: 7), CGRect(x: 13, y: 14, width: 7, height: 7), CGRect(x: 2, y: 3, width: 7, height: 7)] { // grid: ok optical glyph geometry on a 24-point canvas
                    let path = NSBezierPath(roundedRect: box, xRadius: 1, yRadius: 1); path.lineWidth = 1.5; path.stroke()
                }
                NSImage(systemSymbolName: "hand.point.up.left.fill", accessibilityDescription: nil)?.draw(in: CGRect(x: 11, y: 1, width: 13, height: 13)) // grid: ok hand silhouette fits the open grid cell
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = self == .wheel ? "Quick controls" : "All pointers"
        return image
    }
}

struct PracticeStepGlyph: View {
    let lesson: PracticeLesson
    var body: some View {
        Group {
            if lesson == .radial { Image(nsImage: UsabilityGlyph.wheel.image).resizable().scaledToFit().frame(width: 20, height: 20) }
            else { Image(systemName: lesson.symbol) }
        }.accessibilityHidden(true)
    }
}

/// Menu labels use AppKit image sizes, so fit the artwork into actual image
/// bytes rather than relying on SwiftUI's resizable modifier inside a Menu.
func fittedPointerImage(_ source: NSImage?, side: CGFloat, editBadge: Bool = false) -> NSImage {
    NSImage(size: CGSize(width: side, height: side), flipped: false) { rect in
        if let source, source.size.width > 0, source.size.height > 0 {
            let scale = min(side / source.size.width, side / source.size.height)
            let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
        }
        if editBadge {
            let badge = NSImage(systemSymbolName: "pencil.circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.white, .controlAccentColor]))
            badge?.draw(in: CGRect(x: side - 16, y: 0, width: 16, height: 16))
        }
        return true
    }
}
