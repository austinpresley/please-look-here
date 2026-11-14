import AppKit

enum RenderTest {
    static func run(outPath: String) {
        _ = NSApplication.shared

        let env = ProcessInfo.processInfo.environment
        let scene = env["TH_PRESENTATION_SCENE"] == "1"
        let dark = env["TH_DARK"] != nil
        let panel = scene ? CGSize(width: 720, height: 480) : CGSize(width: 420, height: 560)
        let styles = env["TH_RENDER_STYLES"].map { $0.split(separator: ",").compactMap { PointerStyle(rawValue: String($0)) } } ?? PointerStyle.allCases
        let target = scene ? CGPoint(x: 336, y: 205) : CGPoint(x: panel.width - 230, y: 380)
        let w = Int(panel.width) * styles.count
        let h = Int(panel.height)

        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            exit(3)
        }

        for (i, style) in styles.enumerated() {
            ctx.saveGState()
            ctx.translateBy(x: CGFloat(i) * panel.width, y: 0)
            ctx.setFillColor(scene ? Ink.hex(dark ? 0x222330 : 0xF6F3ED) : CGColor(red: 0.93, green: 0.94, blue: 0.92, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: panel.width, height: panel.height))
            if scene { drawPresentationScene(in: ctx, panel: panel, dark: dark) }

            let view = ArmView(frame: NSRect(origin: .zero, size: panel))
            view.setStyle(style)
            let resting = ProcessInfo.processInfo.environment["TH_RESTING"] != nil
            if !resting {
                view.press()
                view.held = true
            }
            let center = CGPoint(x: target.x + 40, y: target.y - 8)
            let a0 = atan2(target.y - center.y, target.x - center.x)
            for k in 0...60 {
                let a = a0 + CGFloat(k) / 60 * 2 * .pi
                let p = CGPoint(x: center.x + 40 * cos(a), y: center.y + 32 * sin(a))
                if k == 0 {
                    view.ink.begin(at: p, width: view.inkWidth)
                } else {
                    view.ink.extend(to: p)
                }
            }
            view.ink.extend(to: target)
            if resting {
                view.ink.clear()
            }
            view.aim(cursor: target)
            view.layer?.render(in: ctx)

            if style != .laser && ProcessInfo.processInfo.environment["TH_NO_MARKER"] == nil {
                ctx.setFillColor(CGColor(red: 0.95, green: 0.8, blue: 0.1, alpha: 1))
                ctx.fillEllipse(in: CGRect(x: target.x - 3, y: target.y - 3, width: 6, height: 6))
            }
            ctx.restoreGState()
        }

        guard let cg = ctx.makeImage() else {
            exit(4)
        }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            exit(5)
        }
        try? data.write(to: URL(fileURLWithPath: outPath))
        print("rendered \(outPath)  \(w)x\(h)")
    }

    private static func drawPresentationScene(in context: CGContext, panel: CGSize, dark: Bool) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let color = NSColor(cgColor: Ink.hex(dark ? 0xEEE9E1 : 0x332C3A))!
        func text(_ value: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular) {
            NSAttributedString(string: value, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]).draw(at: point)
        }
        text("A clearer way to present", at: CGPoint(x: 40, y: panel.height - 76), size: 28, weight: .semibold)
        text("Point to the part that matters.", at: CGPoint(x: 40, y: panel.height - 108), size: 16)
        for index in 0..<3 {
            let rect = CGRect(x: 40 + CGFloat(index) * 216, y: 92, width: 200, height: 208)
            context.setFillColor(Ink.hex(dark ? 0x353645 : 0xFFFFFF))
            context.addPath(CGPath(roundedRect: rect, cornerWidth: 16, cornerHeight: 16, transform: nil))
            context.fillPath()
            context.setFillColor(Ink.hex([0xEE6B61, 0x8F75CE, 0x419B85][index]))
            context.fillEllipse(in: CGRect(x: rect.minX + 20, y: rect.maxY - 64, width: 36, height: 36))
            text(["Choose", "Explain", "Keep moving"][index], at: CGPoint(x: rect.minX + 20, y: rect.maxY - 104), size: 18, weight: .semibold)
            text(["Find your pointer.", "Show one detail.", "Stay in the flow."][index], at: CGPoint(x: rect.minX + 20, y: rect.maxY - 136), size: 13)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
