import AppKit
import Metal
import MetalKit

/// Integrates an area light against the tilted hand silhouette on the GPU.
/// This keeps the same geometric construction as the reference CPU version.
final class AreaLightGPU {
    static let shared = AreaLightGPU()
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let loader: MTKTextureLoader
    private init() {
        device = MTLCreateSystemDefaultDevice()!
        queue = device.makeCommandQueue()!
        loader = MTKTextureLoader(device: device)
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        kernel void areaShadow(texture2d<float, access::sample> shape [[texture(0)]],
                               texture2d<float, access::write> result [[texture(1)]],
                               constant float4 *lights [[buffer(0)]],
                               constant float4 *geometry [[buffer(1)]],
                               uint2 p [[thread_position_in_grid]]) {
            if (p.x >= result.get_width() || p.y >= result.get_height()) return;
            constexpr sampler read(coord::normalized, address::clamp_to_zero, filter::linear);
            float2 point = float2(geometry[0].x + float(p.x) + 0.5,
                                  geometry[0].y - float(p.y) - 0.5);
            float tipY = geometry[1].z;
            float count = geometry[1].w;
            float total = 0;
            for (uint i = 0; i < uint(count); i++) {
                float4 light = lights[i];
                float y = (point.y - light.y * tipY - light.w) / (1 - light.y);
                float x = point.x - light.x * (tipY - y) - light.z;
                float2 uv = float2(x / geometry[1].x, y / geometry[1].y);
                total += shape.sample(read, uv).a;
            }
            result.write(float4(0, 0, 0, total / count), p);
        }
        """
        let library = try! device.makeLibrary(source: source, options: nil)
        pipeline = try! device.makeComputePipelineState(function: library.makeFunction(name: "areaShadow")!)
    }
    func render(silhouette: CGImage, source: CGRect, extent: CGRect,
                tipY: CGFloat, lights: [SIMD4<Float>]) -> CGImage {
        let input = try! loader.newTexture(cgImage: silhouette, options: [
            .origin: MTKTextureLoader.Origin.bottomLeft.rawValue,
            .SRGB: false,
            .textureUsage: MTLTextureUsage.shaderRead.rawValue
        ])
        let w = Int(extent.width), h = Int(extent.height)
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
            width: w, height: h, mipmapped: false)
        desc.usage = [.shaderWrite, .shaderRead]
        desc.storageMode = .shared
        let result = device.makeTexture(descriptor: desc)!
        let command = queue.makeCommandBuffer()!
        let encoder = command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(result, index: 1)
        let bytes = device.makeBuffer(bytes: lights, length: lights.count * MemoryLayout<SIMD4<Float>>.stride)!
        encoder.setBuffer(bytes, offset: 0, index: 0)
        var geometry = [SIMD4<Float>(Float(extent.minX), Float(extent.maxY), Float(w), Float(h)),
            SIMD4<Float>(Float(source.width), Float(source.height), Float(tipY), Float(lights.count))]
        encoder.setBytes(&geometry, length: geometry.count * MemoryLayout<SIMD4<Float>>.stride, index: 1)
        let tw = pipeline.threadExecutionWidth
        let th = max(1, min(8, pipeline.maxTotalThreadsPerThreadgroup / tw))
        encoder.dispatchThreads(MTLSize(width: w, height: h, depth: 1),
            threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
        encoder.endEncoding()
        command.commit(); command.waitUntilCompleted()
        precondition(command.error == nil, "Area-light GPU rendering failed")
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        result.getBytes(&pixels, bytesPerRow: w * 4,
            from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(pixels) as CFData)!, decode: nil,
            shouldInterpolate: true, intent: .defaultIntent)!
    }
}
