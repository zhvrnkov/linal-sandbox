import Foundation
import MetalPerformanceShaders

final class GraphKernel: Kernel {
    
    override class var kernelName: String {
        "graph"
    }
    
    var matrix: matrix_float3x3 = .identity
    var color: vector_float4 = .one
    
    private let function: MTLFunction
    private lazy var vft: MTLVisibleFunctionTable = {
        let descriptor = MTLVisibleFunctionTableDescriptor()
        descriptor.functionCount = 1
        let vft = pipelineState.makeVisibleFunctionTable(descriptor: descriptor)!
        
        let functionHandle = pipelineState.functionHandle(function: function)
        
        vft.setFunction(functionHandle, index: 0)
        return vft
    }()
    
    init(context: MTLContext, f: String) {
        let source = """
#include <metal_stdlib>
using namespace metal;

[[visible]]
float f(const float x, const float time)
{
    return \(f);
}
"""
        let library = try! context.device.makeLibrary(source: source, options: nil)
        function = library.makeFunction(name: "f")!
        
        super.init(context: context)
    }
    
    func callAsFunction(
        commandBuffer: MTLCommandBuffer,
        destinationTexture: MTLTexture
    ) {
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.set(value: &time, index: 0)
        encoder.set(value: &matrix, index: 1)
        encoder.setVisibleFunctionTable(vft, bufferIndex: 2)
        encoder.set(value: &color, index: 3)
        encoder.setTexture(destinationTexture, index: 0)
        encoder.dispatch2d(state: pipelineState, size: destinationTexture.size)
        encoder.endEncoding()
    }
    
    override func makeComputePipelineState(functionName: String) throws -> MTLComputePipelineState {
        let lib = context.library
        
        let linkedFunctions = MTLLinkedFunctions()
        linkedFunctions.functions = [function]
        
        let descriptor = MTLComputePipelineDescriptor()
        descriptor.linkedFunctions = linkedFunctions
        descriptor.computeFunction = lib.makeFunction(name: functionName)!

        return try context.device.makeComputePipelineState(descriptor: descriptor, options: [], reflection: nil)
    }
}
