import MetalKit
import UIKit

/// Draws the owner's photo as a warped mesh on the GPU. The shader is compiled
/// at run time from source, so the build needs no Metal toolchain; where Metal
/// is missing the agent view falls back to a still photo.
final class PortraitRenderer: NSObject, MTKViewDelegate {
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position;
        float2 uv;
        float4 color;
    };

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
        float4 color;
    };

    // frame.xy: the photo point at the centre of the view; frame.zw: clip units per photo unit.
    vertex VertexOut portraitVertex(const device VertexIn *vertices [[buffer(0)]],
                                    constant float4 &frame [[buffer(1)]],
                                    uint vid [[vertex_id]]) {
        VertexIn v = vertices[vid];
        float2 p = (v.position - frame.xy) * frame.zw;
        VertexOut out;
        out.position = float4(p.x, -p.y, 0.0, 1.0);
        out.uv = v.uv;
        out.color = v.color;
        return out;
    }

    fragment float4 portraitFragment(VertexOut in [[stage_in]],
                                     texture2d<float> photo [[texture(0)]],
                                     sampler photoSampler [[sampler(0)]]) {
        float4 c = photo.sample(photoSampler, in.uv) * in.color;
        return float4(c.rgb * c.a, c.a);
    }
    """

    /// Builds the render pipeline, or throws if the shader doesn't compile.
    static func makePipeline(device: MTLDevice, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
        let library = try device.makeLibrary(source: shaderSource, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "portraitVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "portraitFragment")
        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = pixelFormat
        attachment.isBlendingEnabled = true
        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add
        attachment.sourceRGBBlendFactor = .one
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private let texture: MTLTexture
    private let indexBuffer: MTLBuffer
    private let indexCount: Int
    private let mesh: PortraitMesh
    private let view: PortraitView
    private let startTime = CACurrentMediaTime()

    var mood: AgentMood = .idle
    var reduceMotion = false

    init?(view mtkView: MTKView, photo: CGImage, calibration: PortraitCalibration) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        guard let pipeline = try? PortraitRenderer.makePipeline(device: device, pixelFormat: mtkView.colorPixelFormat),
              let texture = try? MTKTextureLoader(device: device).newTexture(
                  cgImage: photo,
                  options: [.SRGB: false, .textureUsage: MTLTextureUsage.shaderRead.rawValue]
              ) else { return nil }
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else { return nil }

        let aspect = Double(photo.width) / Double(max(photo.height, 1))
        let mesh = PortraitMesh(calibration: calibration, aspect: aspect)
        let indices = mesh.indices()
        guard let indexBuffer = device.makeBuffer(
            bytes: indices,
            length: indices.count * MemoryLayout<UInt16>.stride,
            options: .storageModeShared
        ) else { return nil }

        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.sampler = sampler
        self.texture = texture
        self.indexBuffer = indexBuffer
        indexCount = indices.count
        self.mesh = mesh
        view = PortraitMath.view(calibration, aspect: aspect)
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in mtkView: MTKView) {
        guard let pass = mtkView.currentRenderPassDescriptor,
              let drawable = mtkView.currentDrawable,
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        let seconds = CACurrentMediaTime() - startTime
        let mouth = mood == .speaking ? PortraitMath.speechMouth(seconds) : 0
        let pose = PortraitMath.pose(mood, seconds: seconds, mouth: mouth, reduceMotion: reduceMotion)
        let vertices = mesh.vertices(for: pose)
        guard let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.stride,
            options: .storageModeShared
        ) else {
            encoder.endEncoding()
            return
        }

        // Fit the framed close-up's height to the view; the photo is `aspect` wide per unit high.
        let size = mtkView.drawableSize
        let viewAspect = size.height > 0 ? Double(size.width / size.height) : 1
        let perUnitY = 2 / view.height
        var frame = SIMD4<Float>(
            Float(view.center.x),
            Float(view.center.y),
            Float(perUnitY * mesh.aspect / viewAspect),
            Float(perUnitY)
        )

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&frame, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }
}
