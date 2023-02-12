//
//  DotsPlotKernel.swift
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 1/24/23.
//

import Foundation
import MetalPerformanceShaders

final class DotsPlotKernel: PlotKernel<vector_float2> {
    override var points: [vector_float2] {
        didSet {
            updatePointsBuffer()
        }
    }
    var radius: Float = 0.01
    
    init(context: MTLContext) {
        self.context = context
    }
    
    private let context: MTLContext
    private lazy var pipelineState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor(
            vertexFunction: "dots_plot_vertex",
            fragmentFunction: "dots_plot_fragment",
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
        encoder: MTLRenderCommandEncoder
    ) {
        let linesCount = points.count - 1

        var matrixInverse = matrix.inverse
        var pointsCount = Int32(points.count)

        encoder.setRenderPipelineState(pipelineState)
        
        encoder.setVertexBuffer(pointsBuffer, offset: 0, index: 0)
        encoder.set(vertexValue: &pointsCount, index: 1)
        encoder.set(vertexValue: &time, index: 2)
        encoder.set(vertexValue: &matrix, index: 3)
        encoder.set(vertexValue: &matrixInverse, index: 4)
        encoder.set(vertexValue: &radius, index: 5)
        
        encoder.set(fragmentValue: &color, index: 0)
        
        encoder.drawPrimitives(
            type: .triangleStrip,
            vertexStart: 0,
            vertexCount: 4,
            instanceCount: points.count
        )
    }
}
