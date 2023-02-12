//
//  PlotKernel.swift
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 1/17/23.
//

import Foundation
import MetalPerformanceShaders

class PlotKernel<Point> {
    var time: Float = .zero
    var matrix: matrix_float3x3 = .identity
    var points: [Point] = []
    var color: vector_float4 = .one
    
    func callAsFunction(
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
    
    func callAsFunction(
        encoder: MTLRenderCommandEncoder
    ) {
        fatalError()
    }
}
