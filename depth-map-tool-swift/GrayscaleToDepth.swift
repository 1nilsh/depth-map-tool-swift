//
//  GrayscaleToDepthConverter.swift
//  depth-map-tool-swift
//
//  Created by Nils Hodys on 02.03.25.
//

import CoreMedia
import CoreVideo
import AVFoundation

class GrayscaleToDepthConverter {
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    private let computePipelineState: MTLComputePipelineState
    private let commandQueue: MTLCommandQueue
    private var textureCache: CVMetalTextureCache!
    
    init() throws {
        let library = try metalDevice.makeLibrary(source: metalSource, options: nil)
        
        guard let function = library.makeFunction(name: "grayscaleToDepth"),
              let pipelineState = try? metalDevice.makeComputePipelineState(function: function),
              let queue = metalDevice.makeCommandQueue() else {
            fatalError("Metal initialization failed")
        }
        self.computePipelineState = pipelineState
        self.commandQueue = queue
        
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textureCache)
    }
    

    func render(input: CVPixelBuffer) -> CVPixelBuffer? {
        let outputBuffer = createPixelBuffer(from: input)
        
        guard let inputTexture = makeTexture(from: input, format: .bgra8Unorm),
              let outputTexture = makeTexture(from: outputBuffer, format: .r16Float),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        
        let threadGroupSize = MTLSizeMake(computePipelineState.threadExecutionWidth, 1, 1)
        let threadGroups = MTLSizeMake((inputTexture.width + threadGroupSize.width - 1) / threadGroupSize.width, inputTexture.height, 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outputBuffer
    }
    
    private func createPixelBuffer(from input: CVPixelBuffer) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferMetalCompatibilityKey as String: kCFBooleanTrue!] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, CVPixelBufferGetWidth(input), CVPixelBufferGetHeight(input), kCVPixelFormatType_DisparityFloat16, attrs, &pixelBuffer)
        
        return pixelBuffer!
    }
    
    private func makeTexture(from buffer: CVPixelBuffer, format: MTLPixelFormat) -> MTLTexture? {
        var texture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, buffer, nil, format, CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &texture)
        return texture.flatMap { CVMetalTextureGetTexture($0) }
    }
    
    private let metalSource = """
#include <metal_stdlib>
using namespace metal;

struct converterParameters {
    float offset;
    float range;
};

// Compute kernel
kernel void grayscaleToDepth(texture2d<float, access::read>  inputTexture      [[ texture(0) ]],
                             texture2d<float, access::write> outputTexture     [[ texture(1) ]],
                             uint2 gid [[ thread_position_in_grid ]])
{
    // Don't read or write outside of the texture.
    if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) {
        return;
    }
    
    float min = 1.26269531;
    float max = 6.80859375;
    
    float grayScale = inputTexture.read(gid).x;
    float v = min + (max - min) * grayScale;
    
    float4 outputColor = float4(float3(v), 1.0);
    
    outputTexture.write(outputColor, gid);
}
"""
}
