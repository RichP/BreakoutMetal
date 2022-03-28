//
//  Renderer.swift
//  Breakout Shared
//
//  Created by Richard Pickup on 14/03/2022.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 3

enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject {
    
    static var device: MTLDevice!
    let commandQueue: MTLCommandQueue
    
    var effects: PostProcessor
    
    var aspectRatio: Float = 1.0
    
    var uniforms = Uniforms()
    
    var game: Game
    
    let startDate = Date()
    
    lazy var camera: OrthographicCamera = {
        let camera = OrthographicCamera(rect: Rectangle(left: 0, right: 800, top: 0, bottom: 600),
                                        near: -1.0,
                                        far: 1.0)
        camera.position = [0, 0, 0]
        
        return camera
    }()
    
    
    init?(metalKitView: MTKView) {
        guard let device = metalKitView.device,
              let queue = device.makeCommandQueue() else { return nil }
        Renderer.device = device
        self.commandQueue = queue
        
        metalKitView.colorPixelFormat = .bgra8Unorm_srgb
        metalKitView.depthStencilPixelFormat = .depth32Float
        metalKitView.clearColor = MTLClearColor(red: 1.0,
                                             green: 1.0,
                                             blue: 0.8,
                                             alpha: 1.0)
        
        effects = PostProcessor(metalKitView: metalKitView, width: 800, height: 600)
        
        game = Game(width: 800, height: 600, device: device)
        super.init()
    }
    
    static func loadTexture(device: MTLDevice, imageName: String) throws -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: device)
        
        let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft, .SRGB: true, .generateMipmaps: NSNumber(booleanLiteral: true)]
        
        let fileExtension = URL(fileURLWithPath: imageName).pathExtension.isEmpty ? "png" : nil
        
        guard let url = Bundle.main.url(forResource: imageName, withExtension: fileExtension) else {
            print("Failed to load \(imageName)")
            return try textureLoader.newTexture(name: imageName,
                                                scaleFactor: 1.0,
                                                bundle: Bundle.main,
                                                options: nil)
        }
        
        let texture = try textureLoader.newTexture(URL: url, options: textureLoaderOptions)
        
        print("loaded texture: \(url.lastPathComponent)")
        
        return texture
    }
    
    private func updateGameState() {
        /// Update any game state before rendering
    }
}

extension Renderer: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        
        aspectRatio = Float(size.height) / Float(size.width)
        
        let rect = Rectangle(left: 0, right: 800, top: 0, bottom: 600)
        camera.rect = rect
        
    }
    
    func draw(in view: MTKView) {
        self.updateGameState()
        
        let dt = 1.0 / Float(view.preferredFramesPerSecond)
        
        game.processInput(dt: dt)
        game.update(dt: dt)
        
        effects.shake = game.shake
        effects.chaos = game.chaos
        effects.confuse = game.confuse
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
                  return
              }
        
        
        if let encoder = effects.beginRender(commandBuffer: commandBuffer) {
            uniforms.projectionMatrix = camera.projectionMatrix
            game.render(device: Renderer.device, uniforms: uniforms, renderEncoder: encoder)
            effects.endRender(renderEncoder: encoder)
        }
        
        if let descriptor = view.currentRenderPassDescriptor {
            let time = Float(Date().timeIntervalSince(startDate))
            effects.render(uniforms: uniforms, commandBuffer: commandBuffer, descriptor: descriptor, dt: time)
        }
        
        guard let drawable = view.currentDrawable else {
            return
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
