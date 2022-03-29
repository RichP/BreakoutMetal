//
//  PostProcessor.swift
//  Breakout
//
//  Created by Richard Pickup on 22/03/2022.
//

import Foundation
import MetalKit

class PostProcessor {
    let width: Int
    let height: Int
    
    var renderTargetTexture: MTLTexture?
    var depthTargetTexture: MTLTexture?
    var texRenderPassDescriptor: MTLRenderPassDescriptor
    var drawablePipeline: MTLRenderPipelineState!
    var depthStencilState: MTLDepthStencilState?
    
    var confuse: Bool = false
    var chaos: Bool = false
    var shake: Bool = false
    
    let quadVertices: [AAPLTextureVertex] = [
        AAPLTextureVertex(position: float2(1.0,  -1.0), texcoord: float2(1.0, 1.0)),
        AAPLTextureVertex(position: float2(-1.0,  -1.0), texcoord: float2(0.0, 1.0)),
        AAPLTextureVertex(position: float2(-1.0,  1.0), texcoord: float2(0.0, 0.0)),
        
        AAPLTextureVertex(position: float2(1.0,  -1.0), texcoord: float2(1.0, 1.0)),
        AAPLTextureVertex(position: float2(-1.0,  1.0), texcoord: float2(0.0, 0.0)),
        AAPLTextureVertex(position: float2(1.0,  1.0), texcoord: float2(1.0, 0.0))
    ]
    
    var offsets: (float2, float2,
                  float2,float2,
                  float2,float2,
                  float2,float2, float2)!
    
    var edge_kernel = (Int32(-1), Int32(-1), Int32(-1),
                       Int32(-1),  Int32(8), Int32(-1),
                       Int32(-1), Int32(-1), Int32(-1))
    
    let blur_kernel = (
            Float(1.0 / 16.0), Float(2.0 / 16.0), Float(1.0 / 16.0),
            Float(2.0 / 16.0), Float(4.0 / 16.0), Float(2.0 / 16.0),
            Float(1.0 / 16.0), Float(2.0 / 16.0), Float(1.0 / 16.0)
        )
    
    init(metalKitView: MTKView, width: Int, height: Int) {
        self.width = width
        self.height = height
        
        let texDescriptor = MTLTextureDescriptor()
        texDescriptor.textureType = .type2D
        texDescriptor.width = width
        texDescriptor.height = height
        texDescriptor.pixelFormat = .bgra8Unorm_srgb
        texDescriptor.usage = [.renderTarget, .shaderRead]
        texDescriptor.storageMode = .private
        
        let depthTexDescriptor = MTLTextureDescriptor()
        depthTexDescriptor.textureType = .type2D
        depthTexDescriptor.width = width
        depthTexDescriptor.height = height
        depthTexDescriptor.pixelFormat = .depth32Float
        depthTexDescriptor.usage = [.renderTarget]
        depthTexDescriptor.storageMode = .private
        
        renderTargetTexture = Game.device.makeTexture(descriptor: texDescriptor)
        depthTargetTexture = Game.device.makeTexture(descriptor: depthTexDescriptor)
        
        texRenderPassDescriptor = MTLRenderPassDescriptor()
        texRenderPassDescriptor.colorAttachments[0].texture = renderTargetTexture
        texRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        texRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0,
                                                                               green: 1.0,
                                                                               blue: 0.8,
                                                                               alpha: 1.0)
        texRenderPassDescriptor.colorAttachments[0].storeAction = .store
        texRenderPassDescriptor.depthAttachment.texture = depthTargetTexture
        
        self.depthStencilState = PostProcessor.buildDepthStencilState(device: Game.device)
        
        initRenderData(metalKitView: metalKitView)
    }
    
    static func buildDepthStencilState(device: MTLDevice) -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = false
        return device.makeDepthStencilState(descriptor: descriptor)
    }
    
    func beginRender(commandBuffer: MTLCommandBuffer) -> MTLRenderCommandEncoder? {
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: texRenderPassDescriptor) else {
                  return nil
              }
        
        renderEncoder.label = "Post Processor Offscreen"
        
        if let depthStencilState = depthStencilState {
            renderEncoder.setDepthStencilState(depthStencilState)
        }
        
        return renderEncoder
    }
    
    func endRender(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.endEncoding()
    }
    
    
    

    func render(uniforms: Uniforms, renderEncoder: MTLRenderCommandEncoder?,  dt: Float) {
        if let screenRenderEncoder = renderEncoder {
            var uniforms = uniforms
            uniforms.blur_kernel = blur_kernel
            uniforms.offsets = offsets
            uniforms.edge_kernel = edge_kernel
            uniforms.time = dt
            uniforms.confuse = confuse
            uniforms.chaos = chaos
            uniforms.shake = shake
            
            
            screenRenderEncoder.label = "Drawable Render Pass"
            screenRenderEncoder.setRenderPipelineState(drawablePipeline)
            
            screenRenderEncoder.setVertexBytes(&uniforms,
                                               length: MemoryLayout<Uniforms>.stride,
                                               index: Int(BufferIndexUniforms.rawValue))
            
            screenRenderEncoder.setFragmentBytes(&uniforms,
                                               length: MemoryLayout<Uniforms>.stride,
                                               index: Int(BufferIndexFragmentUniforms.rawValue))
            
            
            screenRenderEncoder.setVertexBytes(quadVertices, length: MemoryLayout<AAPLTextureVertex>.stride * quadVertices.count, index: Int(AAPLVertexInputIndexVertices.rawValue))
            
            
            screenRenderEncoder.setFragmentTexture(renderTargetTexture, index: Int(AAPLTextureInputIndexColor.rawValue))
            
            screenRenderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            
            
        }
    }
    
    func initRenderData(metalKitView: MTKView) {
        let defaultLibrary = Game.device.makeDefaultLibrary()
        let vertProg = defaultLibrary?.makeFunction(name: "simpleVertexShader")
        let fragProg = defaultLibrary?.makeFunction(name: "simpleFragmentShader")
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Drawable Pipeline"
        pipelineStateDescriptor.sampleCount = metalKitView.sampleCount
        pipelineStateDescriptor.vertexFunction = vertProg
        pipelineStateDescriptor.fragmentFunction = fragProg
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineStateDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineStateDescriptor.vertexBuffers[Int(AAPLVertexInputIndexVertices.rawValue)].mutability = .immutable
        
        do {
            drawablePipeline = try Game.device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        
        let offset: Float = 1.0 / 300.0
        
        offsets = (
            float2(-offset,  offset),
            float2(0.0,    offset),
            float2(offset,  offset ),
            float2(-offset,  0.0),
            
            float2(0.0,  0.0),
            float2(offset,  0.0),
            float2(-offset, -offset),
            float2(0.0,   -offset ),
            
            float2(offset, -offset )
        )
        
    }
}
