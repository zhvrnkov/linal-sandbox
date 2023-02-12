//
//  GridKernel.swift
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 1/16/23.
//

import Foundation
import MetalPerformanceShaders

class Kernel {
    
    class var kernelName: String {
        ""
    }
    
    var time: Float = 0
    
    let context: MTLContext
    private(set) lazy var pipelineState = try! self.makeComputePipelineState(functionName: Self.kernelName)
    
    init(context: MTLContext) {
        self.context = context
    }
    
    func makeComputePipelineState(functionName: String) throws -> MTLComputePipelineState {
        return try context.makeComputePipelineState(functionName: functionName)
    }
}

final class GridKernel: Kernel {
    
    override class var kernelName: String {
        "grid"
    }
    
    var matrix: matrix_float3x3 = .identity
    
    func callAsFunction(
        commandBuffer: MTLCommandBuffer,
        destinationTexture: MTLTexture
    ) {
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.set(value: &time, index: 0)
        encoder.set(value: &matrix, index: 1)
        encoder.setTexture(destinationTexture, index: 0)
        encoder.dispatch2d(state: pipelineState, size: destinationTexture.size)
        encoder.endEncoding()
    }
}
