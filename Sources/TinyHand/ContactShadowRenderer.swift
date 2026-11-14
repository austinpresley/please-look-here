import AppKit
import CoreImage
import Metal
import MetalKit

/// Serial background owner of the Metal pipeline, image context and render work.
/// Each view submits at most one job and keeps only its newest pending pose.
actor ContactShadowRenderer {
    static let shared = ContactShadowRenderer()
    private var gpu: ContactShadowGPU?
    private var attemptedGPU = false
    private lazy var images = CIContext(options: [.useSoftwareRenderer: false])

    func render(_ pose: ContactShadowPose) -> ContactShadowImage? {
        let began = CACurrentMediaTime()
        if !attemptedGPU {
            attemptedGPU = true
            gpu = ContactShadowGPU()
            if gpu == nil {
                DispatchQueue.main.async { Log.write("Contact shadow unavailable; using the original shadow") }
            }
        }
        guard let gpu, pose.width.isFinite, pose.height.isFinite, pose.rodLength.isFinite,
              pose.rotation.isFinite, pose.press.isFinite,
              pose.width > 0, pose.height > 0, pose.rodLength > 0 else { return nil }
        let asset = pose.asset
        let contact = min(1, max(0, pose.press))
        let hover = 1 - contact
        // Above the surface, even the fingertip casts a broad penumbra. Its
        // light projections meet at the fingertip only once the hand taps down.
        let projectionTipY = pose.tip.y + pose.height * 0.28 * hover
        let density = 0.32 + 0.38 * contact
        let totalHeight = pose.rodLength + pose.height
        // The very distant rod shadow is already diffuse. Fade that part out
        // before rendering instead of allocating a display-sized bitmap.
        let lower = max(0, pose.tip.y - pose.height * 3.2)
        let left = max(0, (min(asset.handMinX, asset.rodX - 0.03) * pose.width - 2).rounded(.down))
        let right = min(pose.width, (max(asset.handMaxX, asset.rodX + 0.03) * pose.width + 2).rounded(.up))
        let source = CGRect(x: left, y: lower, width: right - left, height: totalHeight - lower)
        let maskScale = min(2, 1024 / max(source.width, source.height))
        guard let mask = CGContext(data: nil, width: max(1, Int(ceil(source.width * maskScale))),
            height: max(1, Int(ceil(source.height * maskScale))), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        mask.scaleBy(x: maskScale, y: maskScale)
        mask.translateBy(x: -source.minX, y: -source.minY)
        mask.interpolationQuality = .high

        func crop(_ start: CGFloat, _ end: CGFloat) -> CGImage? {
            asset.image.cropping(to: CGRect(x: 0, y: start * CGFloat(asset.image.height),
                width: CGFloat(asset.image.width), height: (end - start) * CGFloat(asset.image.height)))
        }
        guard let hand = crop(asset.handTop, asset.wrist), let rod = crop(asset.wrist, asset.rodEnd) else { return nil }
        mask.draw(rod, in: CGRect(x: 0, y: 0, width: pose.width, height: pose.rodLength))
        mask.draw(hand, in: CGRect(x: 0, y: pose.rodLength, width: pose.width, height: pose.height))
        mask.setBlendMode(.sourceIn)
        let palm = max(0.01, (pose.tip.y - pose.height * 0.85 - lower) / source.height)
        let nearTip = max(palm + 0.01, (pose.tip.y - pose.height * 0.12 - lower) / source.height)
        let tip = min(0.999, (pose.tip.y - lower) / source.height)
        let colors = [0.26, 0.48, 0.72, 0.98, 0.98].map {
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: $0 * density)
        } as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                       locations: [0, palm, nearTip, tip, 1]) else { return nil }
        mask.drawLinearGradient(gradient, start: CGPoint(x: 0, y: lower),
            end: CGPoint(x: 0, y: totalHeight), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        if lower > 0 {
            mask.setBlendMode(.destinationIn)
            let fade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 1)] as CFArray,
                locations: [0, 1])!
            mask.drawLinearGradient(fade, start: CGPoint(x: 0, y: lower),
                end: CGPoint(x: 0, y: lower + pose.height * 0.5), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        guard let silhouette = mask.makeImage() else { return nil }

        let samples = 1024
        let flatten = 1 - 0.34 * contact
        let bias = CGSize(width: -0.65 * pose.height / 180, height: -0.35 * pose.height / 180)
        var lights: [SIMD4<Float>] = []
        lights.reserveCapacity(samples)
        var extent = CGRect.null
        for i in 0..<samples {
            let u = (CGFloat(i) + 0.5) / CGFloat(samples)
            let radius = sqrt(-2 * log(1 - u)) * (0.16 + 0.07 * hover)
            let angle = CGFloat(i) * 2.399963229728653
            let direction = CGSize(width: (-0.49 + radius * cos(angle)) * flatten,
                                   height: (-0.37 + radius * sin(angle)) * flatten)
            let transform = ShadowProjection.transform(direction: direction, rotation: pose.rotation,
                                                       tipY: projectionTipY, bias: bias)
            lights.append(SIMD4<Float>(Float(-transform.c), Float(1 - transform.d),
                Float(transform.tx + transform.c * projectionTipY),
                Float(transform.ty - (1 - transform.d) * projectionTipY)))
            extent = extent.union(source.applying(transform))
        }
        let blur = 1 + pose.height * (0.006 + 0.024 * hover)
        extent = extent.insetBy(dx: -max(2, blur * 3), dy: -max(2, blur * 3)).integral
        let scale = min(1, 1024 / max(extent.width, extent.height))
        guard let image = gpu.render(silhouette: silhouette, source: source, extent: extent,
                                    tipY: projectionTipY, lights: lights, scale: scale) else { return nil }
        let input = CIImage(cgImage: image)
        let smooth = input.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur * scale])
        let result = images.createCGImage(smooth, from: input.extent) ?? image
        return ContactShadowImage(image: result, extent: extent, pose: pose,
                                  milliseconds: (CACurrentMediaTime() - began) * 1000)
    }
}

/// Used only by ContactShadowRenderer's actor. Failure leaves the original
/// Core Animation shadow available rather than terminating the app.
private final class ContactShadowGPU {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let loader: MTKTextureLoader

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.queue = queue
        loader = MTKTextureLoader(device: device)
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        kernel void contactShadow(texture2d<float, access::sample> shape [[texture(0)]],
                                  texture2d<float, access::write> result [[texture(1)]],
                                  constant float4 *lights [[buffer(0)]],
                                  constant float4 *geometry [[buffer(1)]],
                                  uint2 p [[thread_position_in_grid]]) {
            if (p.x >= result.get_width() || p.y >= result.get_height()) return;
            constexpr sampler read(coord::normalized, address::clamp_to_zero, filter::linear);
            float2 point = float2(geometry[0].x + (float(p.x) + 0.5) * geometry[0].z,
                                  geometry[0].y - (float(p.y) + 0.5) * geometry[0].z);
            float tipY = geometry[1].z;
            float count = geometry[1].w;
            float total = 0;
            for (uint i = 0; i < uint(count); i++) {
                float4 light = lights[i];
                float y = (point.y - light.y * tipY - light.w) / (1 - light.y);
                float x = point.x - light.x * (tipY - y) - light.z;
                float2 uv = (float2(x, y) - geometry[2].xy) / geometry[1].xy;
                total += shape.sample(read, uv).a;
            }
            result.write(float4(0, 0, 0, total / count), p);
        }
        """
        do {
            let library = try device.makeLibrary(source: source, options: nil)
            guard let function = library.makeFunction(name: "contactShadow") else { return nil }
            pipeline = try device.makeComputePipelineState(function: function)
        } catch { return nil }
    }

    func render(silhouette: CGImage, source: CGRect, extent: CGRect, tipY: CGFloat,
                lights: [SIMD4<Float>], scale: CGFloat) -> CGImage? {
        guard let input = try? loader.newTexture(cgImage: silhouette, options: [
            .origin: MTKTextureLoader.Origin.bottomLeft.rawValue, .SRGB: false,
            .textureUsage: MTLTextureUsage.shaderRead.rawValue
        ]) else { return nil }
        let w = max(1, Int(ceil(extent.width * scale))), h = max(1, Int(ceil(extent.height * scale)))
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
        desc.usage = [.shaderWrite, .shaderRead]
        desc.storageMode = device.hasUnifiedMemory ? .shared : .managed
        guard let result = device.makeTexture(descriptor: desc), let command = queue.makeCommandBuffer(),
              let encoder = command.makeComputeCommandEncoder(),
              let bytes = device.makeBuffer(bytes: lights, length: lights.count * MemoryLayout<SIMD4<Float>>.stride) else { return nil }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(result, index: 1)
        encoder.setBuffer(bytes, offset: 0, index: 0)
        var geometry = [SIMD4<Float>(Float(extent.minX), Float(extent.maxY), Float(1 / scale), 0),
            SIMD4<Float>(Float(source.width), Float(source.height), Float(tipY), Float(lights.count)),
            SIMD4<Float>(Float(source.minX), Float(source.minY), 0, 0)]
        encoder.setBytes(&geometry, length: geometry.count * MemoryLayout<SIMD4<Float>>.stride, index: 1)
        let tw = pipeline.threadExecutionWidth
        let th = max(1, min(8, pipeline.maxTotalThreadsPerThreadgroup / tw))
        encoder.dispatchThreadgroups(MTLSize(width: (w + tw - 1) / tw, height: (h + th - 1) / th, depth: 1),
                                     threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
        encoder.endEncoding()
        if !device.hasUnifiedMemory, let sync = command.makeBlitCommandEncoder() {
            sync.synchronize(resource: result)
            sync.endEncoding()
        }
        command.commit()
        command.waitUntilCompleted()
        guard command.status == .completed else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        result.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
