//
//  FieldKernel.swift
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 2/1/23.
//

import Foundation
import MetalPerformanceShaders

class FieldKernel: ArrowsKernel {
    
    func field(_ position: vector_float2) -> vector_float2 {
        let m: Float = 0.1
        let G: Float = 6.67
        let massPosition = vector_float2.zero
        
        let radiusVector = position - massPosition
        let radius = length(radiusVector)
        
        return -G * m / pow(radius, 2) * normalize(radiusVector)
    }
    
    private lazy var positionsBuffer: MTLBuffer = {
        let step: Float = 0.25
        let stride = stride(from: Float(-4), through: Float(4), by: step)
        var positions = stride.reduce(into: [vector_float2]()) { acc, x in
            acc += stride.map { y in
                let tail = vector_float2(x: Float(x), y: Float(y))
                return tail
            }
        }
        return context.device.makeBuffer(
            bytes: &positions,
            length: MemoryLayout.stride(ofValue: positions[0]) * positions.count
        )!
    }()
    
    private var pointsCount: Int {
        return positionsBuffer.length / MemoryLayout<vector_float2>.stride
    }
    
    private lazy var fieldPipelineState: MTLComputePipelineState = {
        try! context.makeComputePipelineState(functionName: "field_kernel")
    }()
    
    override init(context: MTLContext) {
        super.init(context: context)
        lineThikness = 0.0025
        
        let pointsCount = positionsBuffer.length / MemoryLayout<vector_float2>.stride
        pointsBuffer = context.device.makeBuffer(
            length: MemoryLayout<vector_float4>.stride * pointsCount
        )
    }
    
    override func updatePointsBuffer() {
        // do nothing
    }
    
    override func callAsFunction(commandBuffer: MTLCommandBuffer, destinationTexture: MTLTexture) {
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setBuffer(positionsBuffer, offset: 0, index: 0)
        encoder.setBuffer(pointsBuffer, offset: 0, index: 1)
        encoder.set(value: &time, index: 2)
        encoder.dispatch1d(
            state: fieldPipelineState,
            covering: pointsCount
        )
        encoder.endEncoding()
        
        super.callAsFunction(commandBuffer: commandBuffer, destinationTexture: destinationTexture)
    }
}
