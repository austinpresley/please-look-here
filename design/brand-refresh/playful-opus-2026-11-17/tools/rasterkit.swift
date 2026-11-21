// Small CoreGraphics helper: crop/scale for review boards and resampled tilt derivatives.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func load(_ p: String) -> CGImage {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(src, 0, nil)!
}
func save(_ img: CGImage, _ p: String) {
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: p) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}
func ctx(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
let a = CommandLine.arguments
switch a[1] {
case "nearest": // in out factor
    let img = load(a[2]); let f = Int(a[4])!
    let c = ctx(img.width * f, img.height * f); c.interpolationQuality = .none
    c.draw(img, in: CGRect(x: 0, y: 0, width: img.width * f, height: img.height * f)); save(c.makeImage()!, a[3])
case "crop": // in out x y w h (top-left origin)
    let img = load(a[2]); let r = CGRect(x: Int(a[4])!, y: Int(a[5])!, width: Int(a[6])!, height: Int(a[7])!)
    save(img.cropping(to: r)!, a[3])
case "tilt": // in out degrees(clockwise) : canvas grows to fit, high-quality resample
    let img = load(a[2]); let deg = Double(a[4])!; let r = -deg * .pi / 180
    let w = Double(img.width), h = Double(img.height)
    let nw = Int((abs(w * cos(r)) + abs(h * sin(r))).rounded(.up)), nh = Int((abs(w * sin(r)) + abs(h * cos(r))).rounded(.up))
    let c = ctx(nw, nh); c.interpolationQuality = .high
    c.translateBy(x: Double(nw) / 2, y: Double(nh) / 2); c.rotate(by: r)
    c.draw(img, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h)); save(c.makeImage()!, a[3])
default: fatalError("unknown command")
}
