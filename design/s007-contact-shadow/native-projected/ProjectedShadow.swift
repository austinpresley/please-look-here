import AppKit
import CoreImage

/// Prototype of a tilted, fingertip-anchored silhouette under an area light.
/// Every light sample meets at the same contact point. Its projection spreads
/// farther from that point, producing a penumbra without a radial tip decal.
enum ProjectedShadow {
    private static let imageContext = CIContext(options: [.useSoftwareRenderer: false])
    static func make(asset: HandAsset, handWidth: CGFloat, handHeight: CGFloat,
                     rodLength: CGFloat, rotation: CGFloat, press: CGFloat) -> (CGImage, CGRect)? {
        let scale: CGFloat = 2
        let totalHeight = rodLength + handHeight
        let w = max(1, Int(ceil(handWidth * scale)))
        let h = max(1, Int(ceil(totalHeight * scale)))
        let tipY = rodLength + (asset.wrist - asset.tip) * handHeight / (asset.wrist - asset.handTop)
        guard let mask = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        mask.scaleBy(x: scale, y: scale)
        mask.interpolationQuality = .high

        func crop(_ start: CGFloat, _ end: CGFloat) -> CGImage? {
            asset.image.cropping(to: CGRect(x: 0, y: start * CGFloat(asset.image.height),
                width: CGFloat(asset.image.width), height: (end - start) * CGFloat(asset.image.height)))
        }
        guard let hand = crop(asset.handTop, asset.wrist),
              let rod = crop(asset.wrist, asset.rodEnd) else { return nil }
        mask.draw(rod, in: CGRect(x: 0, y: 0, width: handWidth, height: rodLength))
        mask.draw(hand, in: CGRect(x: 0, y: rodLength, width: handWidth, height: handHeight))
        mask.setBlendMode(.sourceIn)
        let nearPalm = max(0.01, (tipY - handHeight * 0.85) / totalHeight)
        let nearTip = max(nearPalm + 0.01, (tipY - handHeight * 0.12) / totalHeight)
        let tip = min(0.999, tipY / totalHeight)
        let colors = [0.26, 0.48, 0.72, 0.98, 0.98].map {
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: $0)
        } as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
            locations: [0, nearPalm, nearTip, tip, 1])!
        mask.drawLinearGradient(gradient, start: .zero,
            end: CGPoint(x: 0, y: totalHeight), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        guard let silhouette = mask.makeImage() else { return nil }

        let source = CGRect(x: 0, y: 0, width: handWidth, height: totalHeight)
        let samples = 1024
        let flatten = 1 - 0.34 * press
        let c = cos(rotation), s = sin(rotation)
        var lights: [SIMD4<Float>] = []
        var extent = CGRect.null
        for i in 0..<samples {
            let u = (CGFloat(i) + 0.5) / CGFloat(samples)
            let radius = sqrt(-2 * log(1 - u)) * 0.14
            let angle = CGFloat(i) * 2.399963229728653
            // Fixed light from the upper right, matching the reference study.
            let screenX = (-0.49 + radius * cos(angle)) * flatten
            let screenY = (-0.37 + radius * sin(angle)) * flatten
            let lx = screenX * c + screenY * s
            let ly = -screenX * s + screenY * c
            let contactX: CGFloat = -0.65 * handHeight / 180
            let contactY: CGFloat = -0.35 * handHeight / 180
            let bx = contactX * c + contactY * s
            let by = -contactX * s + contactY * c
            let transform = CGAffineTransform(a: 1, b: 0, c: -lx, d: 1 - ly,
                tx: lx * tipY + bx, ty: ly * tipY + by)
            lights.append(SIMD4<Float>(Float(lx), Float(ly), Float(bx), Float(by)))
            extent = extent.union(source.applying(transform))
        }
        extent = extent.insetBy(dx: -2, dy: -2).integral
        let image = AreaLightGPU.shared.render(silhouette: silhouette, source: source,
            extent: extent, tipY: tipY, lights: lights)
        // Subpixel antialiasing only. The broad penumbra comes from the
        // height-dependent light projections, rather than this tiny filter.
        let input = CIImage(cgImage: image)
        let smooth = input.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.65])
        guard let final = imageContext.createCGImage(smooth, from: input.extent) else { return nil }
        return (final, extent)
    }
}
