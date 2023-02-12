//
//  ArrowsKernel.swift
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 2/1/23.
//

import Foundation
import MetalPerformanceShaders

class ArrowsKernel: PlotKernel<vector_float4> {
    
    override var points: [vector_float4] {
        didSet {
            updatePointsBuffer()
        }
    }
    var lineThikness: Float = 0.025
    
    init(context: MTLContext) {
        self.context = context
    }
    
    let context: MTLContext
    private lazy var pipelineState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor(
            vertexFunction: "arrows_vertex",
            fragmentFunction: "arrows_fragment",
            pixelFormat: .bgra8Unorm,
            library: context.library
        )
        return try! context.device.makeRenderPipelineState(descriptor: descriptor)
    }()
    var pointsBuffer: MTLBuffer?
    private var pointsCount: Int {
        return (pointsBuffer?.length ?? 0) / MemoryLayout<vector_float4>.stride
    }
    
    func updatePointsBuffer() {
        pointsBuffer = context.device.makeBuffer(
            bytes: &points,
            length: MemoryLayout.stride(ofValue: points[0]) * points.count
        )
    }
    
    override func callAsFunction(
        encoder: MTLRenderCommandEncoder
    ) {
        var matrixInverse = matrix.inverse
        var pointsCount = self.pointsCount

        encoder.setRenderPipelineState(pipelineState)
        
        encoder.setVertexBuffer(pointsBuffer, offset: 0, index: 0)
        encoder.set(vertexValue: &pointsCount, index: 1)
        encoder.set(vertexValue: &matrix, index: 2)
        encoder.set(vertexValue: &matrixInverse, index: 3)
        encoder.set(vertexValue: &lineThikness, index: 4)
        
        encoder.set(fragmentValue: &color, index: 0)
        
        encoder.drawPrimitives(
            type: .triangleStrip,
            vertexStart: 0,
            vertexCount: 7,
            instanceCount: pointsCount
        )
    }
}
