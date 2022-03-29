//
//  Spritebatch.swift
//  Breakout
//
//  Created by Richard Pickup on 14/03/2022.
//

import Foundation
import MetalKit

class SpriteBatch {
    
    let texture: MTLTexture
    
    var vertices: [Float] = []
    var count = 0
    let widthRatio: Float
    let heightRatio: Float
    let pipeline: MTLRenderPipelineState!
    let sampler: MTLSamplerState!
    var vertexBuffer: MTLBuffer?
    
    var spriteSheet: SpriteSheet?
    
    let floatSize = MemoryLayout<Float>.stride
    let defaultBatchSize = 6 * 2048
    var renderEncoder: MTLRenderCommandEncoder?
    var uniforms: Uniforms?
    
    init(spriteTexture: MTLTexture, sheetName: String? = nil) {
        texture = spriteTexture
        widthRatio = 1.0 / Float(spriteTexture.width)
        heightRatio = 1.0 / Float(spriteTexture.height)
        pipeline = SpriteBatch.renderPipeline(device: Game.device)
        sampler = SpriteBatch.buildSamplerState(device: Game.device)
        
        if let sheetName = sheetName {
            spriteSheet = SpriteSheet(name: sheetName)
        }
        vertexBuffer = Game.device.makeBuffer(length: defaultBatchSize * floatSize, options: [])
    }
    
    func draw(dest: Rectangle) {
        let src = Rectangle(left: 0, right: Float(texture.width), top: 0, bottom: Float(texture.height))
        draw(dst: float2(dest.left, dest.top), width: dest.right, height: dest.bottom, src: src)
    }
    
    func draw(dest: Rectangle, src: Rectangle, color: vector_float4 = [1, 1, 1, 1]) {
        draw(dst: float2(dest.left, dest.top),
             width: dest.right,
             height: dest.bottom,
             src: src,
             color: color)
    }
    
    func draw(dst: float2, width: Float, height: Float, frameName: String, angle: Float? = nil, color: float4 = float4(1.0, 1.0, 1.0, 1.0)) {
        guard let spriteSheet = spriteSheet else {
            return
        }
        let frame = spriteSheet.frame(name: frameName)
        
        draw(dst: dst, width: width, height: height, src: frame, angle: angle, color: color)
    }
    
    func draw(dst: float2, width: Float, height: Float, src: Rectangle, angle: Float? = nil, color: float4 = float4(1.0, 1.0, 1.0, 1.0)) {
        
        if vertices.count + 6 > defaultBatchSize {
            flush()
        }
        
        let u1 = widthRatio * src.left
        let v1 = 1.0 - heightRatio * src.top
        let u2 = u1 + widthRatio * src.right
        let v2 = v1 - heightRatio * src.bottom
        
        
        let x2 = dst.x + width
        let y2 = dst.y + height
        
        var upLeft = float2(dst.x, dst.y)
        var upRight = float2(x2, dst.y)
        var downLeft = float2(dst.x, y2)
        var downRight = float2(x2, y2)
        
        if let angle = angle, angle != 0 {
            
            var pivot = float2(0.5, 0.5)
            pivot.x *= width
            pivot.y *= height
            pivot.x += dst.x
            pivot.y += dst.y
            
            upLeft = upLeft.rotate(point: pivot, angle: angle)
            upRight = upRight.rotate(point: pivot, angle: angle)
            downLeft = downLeft.rotate(point: pivot, angle: angle)
            downRight = downRight.rotate(point: pivot, angle: angle)
        }
        
        let spriteVerts: [Float] = [
            downLeft.x,downLeft.y, u1, v2, color.x, color.y, color.z, color.w,
            upRight.x, upRight.y,  u2, v1, color.x, color.y, color.z, color.w,
            upLeft.x,  upLeft.y,   u1, v1, color.x, color.y, color.z, color.w,
            
            downLeft.x,  downLeft.y,  u1, v2, color.x, color.y, color.z, color.w,
            downRight.x, downRight.y, u2, v2, color.x, color.y, color.z, color.w,
            upRight.x,   upRight.y,   u2, v1, color.x, color.y, color.z, color.w
        ]
        
        vertices.append(contentsOf: spriteVerts)
        count += 6
    }
    
    func start(uniforms: Uniforms, renderEncoder: MTLRenderCommandEncoder?) {
        self.uniforms = uniforms
        self.renderEncoder = renderEncoder
        vertices = []
        count = 0
    }
    
    func end() {
        flush()
        vertices = []
        count = 0
    }
    
    func flush() {
        guard let encoder = renderEncoder,
              let pipeline = pipeline, vertices.count > 0 else { return }
        
        
        vertexBuffer?.contents().copyMemory(from: vertices, byteCount: vertices.count * floatSize)
        
        
        var uniforms = uniforms
        uniforms?.modelViewMatrix = float4x4.identity()
        
        encoder.label = "SpriteBatch Render Pass"
        if let sampler = sampler {
            encoder.setFragmentSamplerState(sampler,
                                            index: 0)
        }
        encoder.setFragmentTexture(texture, index: Int(BaseColorTexture.rawValue))
        encoder.setVertexBytes(&uniforms,
                               length: MemoryLayout<Uniforms>.stride,
                               index: Int(BufferIndexUniforms.rawValue))
        
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: count)
    }
    
    
    static func renderPipeline(device: MTLDevice) -> MTLRenderPipelineState? {
        let defaultLibrary = device.makeDefaultLibrary()
        let vertProg = defaultLibrary?.makeFunction(name: "sprite_vertex")
        let fragProg = defaultLibrary?.makeFunction(name: "sprite_frag")
        
        var offset = 0
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[Int(Position.rawValue)].format = .float2
        vertexDescriptor.attributes[Int(Position.rawValue)].bufferIndex = 0
        vertexDescriptor.attributes[Int(Position.rawValue)].offset = offset
        
        offset += MemoryLayout<float2>.stride
        
        vertexDescriptor.attributes[Int(UV.rawValue)].format = .float2
        vertexDescriptor.attributes[Int(UV.rawValue)].bufferIndex = 0
        vertexDescriptor.attributes[Int(UV.rawValue)].offset = offset
        
        offset += MemoryLayout<float2>.stride
        
        vertexDescriptor.attributes[3].format = .float4
        vertexDescriptor.attributes[3].bufferIndex = 0
        vertexDescriptor.attributes[3].offset = offset
        
        //offset += MemoryLayout<float4>.stride
        offset += MemoryLayout<Float>.stride * 4
        
        vertexDescriptor.layouts[0].stride = offset
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertProg
        pipelineDescriptor.fragmentFunction = fragProg
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha


        var pipelineState: MTLRenderPipelineState
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        
        return pipelineState
    }
    
    private static func buildSamplerState(device: MTLDevice) -> MTLSamplerState? {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat
        descriptor.mipFilter = .linear
        descriptor.maxAnisotropy = 8
        let samplerState = device.makeSamplerState(descriptor: descriptor)
        return samplerState
    }
}
