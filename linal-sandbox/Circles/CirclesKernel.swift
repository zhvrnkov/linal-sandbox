//
//  CirclesKernel.swift
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 1/16/23.
//

import Foundation
import MetalPerformanceShaders

final class CirclesKernel: Kernel {
    
    override class var kernelName: String {
        "circles"
    }
    
    var matrix: matrix_float3x3 = .identity
    var circles: [vector_float4] = []
    
    func callAsFunction(
        commandBuffer: MTLCommandBuffer,
        destinationTexture: MTLTexture
    ) {
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.set(value: &time, index: 0)
        encoder.set(value: &matrix, index: 1)
        encoder.set(array: &circles, pointerIndex: 2, countIndex: 3)
        encoder.setTexture(destinationTexture, index: 0)
        encoder.dispatch2d(state: pipelineState, size: destinationTexture.size)
        encoder.endEncoding()
    }
}
