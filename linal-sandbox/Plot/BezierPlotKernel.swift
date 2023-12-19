import Foundation
import Metal
import simd

final class BezierPlotKernel: PlotKernel<simd_float2> {
    override var points: [vector_float2] {
        didSet {
            updatePointsBuffer()
        }
    }
    var lineThikness: Float = 0.1

    init(context: MTLContext) {
        self.context = context
    }

    private let context: MTLContext
    private lazy var pipelineState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor(
            vertexFunction: "contourPathVertexShader",
            fragmentFunction: "contourPathFragmentShader",
            pixelFormat: .bgra8Unorm,
            library: context.library
        )
        return try! context.device.makeRenderPipelineState(descriptor: descriptor)
    }()
    private var pointsBuffer: MTLBuffer?

    private func updatePointsBuffer() {
        pointsBuffer = context.device.makeBuffer(
            bytes: &points,
            length: MemoryLayout.stride(ofValue: points[0]) * points.count
        )
    }

    override func callAsFunction(
        commandBuffer: MTLCommandBuffer,
        destinationTexture: MTLTexture
    ) {
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].loadAction = .load
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].texture = destinationTexture

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)!
        self(encoder: encoder)
        encoder.endEncoding()
    }

    override func callAsFunction(
        encoder: MTLRenderCommandEncoder
    ) {
        let linesCount = points.count / 2
        var vertexCount = UInt32(16 * 2)

        var matrixInverse = matrix.inverse
        var pointsCount = Int32(points.count)

        encoder.setRenderPipelineState(pipelineState)

        encoder.setVertexBuffer(pointsBuffer, offset: 0, index: 0)
        encoder.set(vertexValue: &pointsCount, index: 1)
        encoder.set(vertexValue: &time, index: 2)
        encoder.set(vertexValue: &matrix, index: 3)
        encoder.set(vertexValue: &matrixInverse, index: 4)
        encoder.set(vertexValue: &lineThikness, index: 5)
        encoder.set(vertexValue: &vertexCount, index: 6)

        encoder.set(fragmentValue: &color, index: 0)

        encoder.drawPrimitives(
            type: .triangleStrip,
            vertexStart: 0,
            vertexCount: Int(vertexCount),
            instanceCount: linesCount
        )
    }
}
