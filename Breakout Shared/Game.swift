//
//  Renderer.swift
//  Breakout Shared
//
//  Created by Richard Pickup on 14/03/2022.
//

// Our platform independent renderer class

import Metal
import MetalKit
import GameController
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

enum GameState {
    case active
    case menu
    case win
}

class Game: NSObject {
    
    static var device: MTLDevice!
    let commandQueue: MTLCommandQueue
    
    var effects: PostProcessor
    
    var aspectRatio: Float = 1.0
    
    var uniforms = Uniforms()
    
    let startDate = Date()
    
    var state: GameState = .menu
    var keys: [GCKeyCode: Bool] = [:]
    var processedKeys: [GCKeyCode: Bool] = [:]
    
    let width: Int
    let height: Int
    
    let playerSize: float2 = float2(100.0, 20.0)
    let playerVelocity: Float = 500.0
    let ballRadius: Float = 12.5
    let initialBallVelocity: float2 = float2(100.0, -350.0)
    
    let background: MTLTexture?
    var backgroundSprite: SpriteBatch?
    var spriteSheet = SpriteSheet(name: "spritesheet")
    var textRenderer: TextRenderer
    let soundEngine = SoundEngine()
    
    let sprites: MTLTexture?
    var spriteBatch: SpriteBatch?
    
    var levels: [GameLevel] = []
    var powerUps: [PowerUp] = []
    var level: Int = 0
    let player: GameObject
    let ball: Ball
    
    var lives: Int = 3
    
    let particles: ParticleGenerator
    
    var shakeTime: Float = 0.0
    
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
        Game.device = device
        self.commandQueue = queue
        
        metalKitView.colorPixelFormat = .bgra8Unorm_srgb
        metalKitView.depthStencilPixelFormat = .depth32Float
        metalKitView.clearColor = MTLClearColor(red: 1.0,
                                             green: 1.0,
                                             blue: 0.8,
                                             alpha: 1.0)
        
        effects = PostProcessor(metalKitView: metalKitView, width: 800, height: 600)
        
        self.width = 800
        self.height = 600
        
        let font = Font.systemFont(ofSize: 24)
        
        textRenderer = TextRenderer(font: font)
        textRenderer.createTexture(device: Game.device)
        
        self.background = try? Game.loadTexture(device: device, imageName: "background.jpg")
        
        self.sprites = try? Game.loadTexture(device: device, imageName: "spritesheet")
        
        if let background = self.background {
            backgroundSprite = SpriteBatch(spriteTexture: background)
        }
        
        if let sprites = sprites {
            spriteBatch = SpriteBatch(spriteTexture: sprites, sheetName: "spritesheet")
        }
        
        let one = GameLevel()
        one.Load(file: "levels/one", width: width, height: height / 2)
        
        let two = GameLevel()
        two.Load(file: "levels/two", width: width, height: height / 2)
        
        let three = GameLevel()
        three.Load(file: "levels/three", width: width, height: height / 2)
        
        let four = GameLevel()
        four.Load(file: "levels/four", width: width, height: height / 2)
        
        levels.append(contentsOf: [one, two, three, four])
        
        let pos = float2(Float(width) / 2.0 - playerSize.x / 2.0,
                         Float(height) - playerSize.y)
        
        player = GameObject(pos: pos, size: playerSize, spriteFrame: "paddle.png")
        let ballPos = player.position + float2(playerSize.x / 2.0 - ballRadius,
                                               -ballRadius * 2.0)
        ball = Ball(pos: ballPos, radius: ballRadius, velocity: initialBallVelocity,
                    spriteFrame: "awesomeface.png")
        particles = ParticleGenerator(amount: 500)
        
        soundEngine.play2D(file: "audio/breakout.mp3", loop: true)
        
        super.init()
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GCKeyboardDidConnect,
            object: nil,
            queue: OperationQueue.main) { note in
                if let keyboard = GCKeyboard.coalesced?.keyboardInput {
                    keyboard.keyChangedHandler = { (input, button, keyCode, pressed) in
                        
                        self.keys[keyCode] = pressed
                        if !pressed {
                            self.processedKeys[keyCode] = pressed
                        }
                        
                    }
                } else {
                    print("Couldn't find keys")
                }
            }
        
        
        
    }
    
    func processInput(dt: Float) {
        if state == .menu {
            if keys[GCKeyCode.returnOrEnter]  == true,
               processedKeys[GCKeyCode.returnOrEnter, default: false] == false {
                state = .active
                processedKeys[GCKeyCode.returnOrEnter] = true
            }
            
            if keys[GCKeyCode.keyW] == true,
               processedKeys[GCKeyCode.keyW, default: false] == false {
                level = (level + 1) % 4
                processedKeys[GCKeyCode.keyW] = true
            }
            
            if keys[GCKeyCode.keyS] == true,
               processedKeys[GCKeyCode.keyS, default: false] == false{
                if level > 0 {
                    level -= 1
                } else {
                    level = 3
                }
                processedKeys[GCKeyCode.keyS] = true
            }
        }
        if state == .win {
            if keys[GCKeyCode.returnOrEnter] == true {
                processedKeys[GCKeyCode.returnOrEnter] = true
                effects.chaos = false
                state = .menu
            }
        }
        if state == .active {
            let velocity = playerVelocity * dt
            
            if keys[GCKeyCode.keyA] == true {
                if player.position.x >= 0.0 {
                    player.position.x -= velocity
                    if ball.stuck {
                        ball.position.x -= velocity
                    }
                }
            }
            
            if keys[GCKeyCode.keyD] == true {
                if player.position.x <= Float(width) - player.size.x {
                    player.position.x += velocity
                    if ball.stuck {
                        ball.position.x += velocity
                    }
                }
            }
            
            if keys[GCKeyCode.spacebar] == true {
                ball.stuck = false
            }
        }
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
}

extension Game: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        
        aspectRatio = Float(size.height) / Float(size.width)
        
        let rect = Rectangle(left: 0, right: 800, top: 0, bottom: 600)
        camera.rect = rect
        
    }
    
    func draw(in view: MTKView) {
        
        let dt = 1.0 / Float(view.preferredFramesPerSecond)
        processInput(dt: dt)
        update(dt: dt)
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
                  return
              }
        
        
        if let encoder = effects.beginRender(commandBuffer: commandBuffer) {
            uniforms.projectionMatrix = camera.projectionMatrix
            
            renderGame(device: Game.device, uniforms: uniforms, renderEncoder: encoder)
            
            
            effects.endRender(renderEncoder: encoder)
        }
        
        if let descriptor = view.currentRenderPassDescriptor {
            let time = Float(Date().timeIntervalSince(startDate))
            
            if let screenRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
                effects.render(uniforms: uniforms, renderEncoder: screenRenderEncoder, dt: time)
                
                renderText(uniforms: uniforms, renderEncoder: screenRenderEncoder)
                
                screenRenderEncoder.endEncoding()
            }
            
        }
        
        guard let drawable = view.currentDrawable else {
            return
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}


extension Game {
    func update(dt: Float) {
        _ = ball.move(dt: dt, width: width)
        
        doCollisions()
        
        particles.update(dt: dt,
                         object: ball,
                         newParticles: 2,
                         offset: float2(repeating: ball.radius / 2.0))
        
        updatePowerUps(dt: dt)
        
        if shakeTime > 0.0 {
            shakeTime -= dt
            if shakeTime < 0.0 {
                effects.shake = false
            }
        }
        
        if ball.position.y > Float(height) {
            lives -= 1
            
            if lives <= 0 {
                resetLevel()
                state = .menu
            }
            
            resetPlayer()
        }
        
        //do win state
        
    }
}

extension Game {
    func renderGame(device: MTLDevice, uniforms: Uniforms, renderEncoder: MTLRenderCommandEncoder?) {
        
        if state == .active || state == .menu || state == .win {
            backgroundSprite?.start(uniforms: uniforms, renderEncoder: renderEncoder)

            let rect = Rectangle(left: 0.0, right: Float(width), top: 0.0, bottom: Float(height))
            backgroundSprite?.draw(dest: rect)

            backgroundSprite?.end()
            
            
            spriteBatch?.start(uniforms: uniforms, renderEncoder: renderEncoder)
            
            if let spriteBatch = spriteBatch {
                levels[level].draw(spriteBatch: spriteBatch)
                
                player.draw(spriteBatch: spriteBatch)
                
                powerUps.forEach { powerUp in
                    if !powerUp.isDestroyed {
                        powerUp.draw(spriteBatch: spriteBatch)
                    }
                }
                
                particles.draw(spriteBatch: spriteBatch)
                
                ball.draw(spriteBatch: spriteBatch)
            }
            spriteBatch?.end()
        }
        
        
        
        
        
        
    }
    
    func renderText(uniforms: Uniforms, renderEncoder: MTLRenderCommandEncoder?) {
        textRenderer.start(uniforms: uniforms, renderEncoder: renderEncoder)
        if state == .active || state == .menu || state == .win {
            textRenderer.renderText(text: "Lives: \(lives)", x: 5, y: 5, scale: 1, color: float4(1, 1, 1, 1), uniforms: uniforms, renderEncoder: renderEncoder)
        }
        
        if state == .menu {
            var text = "Press Enter to start"
            var textSize = textRenderer.measureString(text)
            textRenderer.renderText(text: text,
                                    x: (Float(width) - textSize.x) * 0.5,
                                    y: Float(height / 2), scale: 1, color: float4(1, 1, 1, 1), uniforms: uniforms, renderEncoder: renderEncoder)
            
            text = "Press W or S to select level"
            textSize = textRenderer.measureString(text)
            textSize *= 0.75
            textRenderer.renderText(text: text,
                                    x: (Float(width) - textSize.x) * 0.5,
                                    y: Float(height / 2) + 20, scale: 0.75, color: float4(1, 1, 1, 1), uniforms: uniforms, renderEncoder: renderEncoder)
        }
        
        if state == .win {
            var text = "You Won!!!"
            var textSize = textRenderer.measureString(text)
            textRenderer.renderText(text: text,
                                    x: (Float(width) - textSize.x) * 0.5,
                                    y: Float(height / 2) - 20, scale: 1, color: float4(0, 1, 0, 1), uniforms: uniforms, renderEncoder: renderEncoder)
            text = "Press ENTER to retry or ESC to quit"
            textSize = textRenderer.measureString(text)
            textRenderer.renderText(text: text,
                                    x: (Float(width) - textSize.x) * 0.5,
                                    y: Float(height / 2) + 20, scale: 1, color: float4(1, 1, 0, 1), uniforms: uniforms, renderEncoder: renderEncoder)
        }
        
        textRenderer.end()
    }
}



extension Game {
    func resetLevel() {
        
        var levelName = "levels/one"
        switch level {
        case 1:
            levelName = "levels/two"
        case 2:
            levelName = "levels/three"
        case 3:
            levelName = "levels/four"
        default:
            levelName = "levels/one"
        }
        levels[level].Load(file: levelName, width: width, height: height / 2)
        lives = 3
    }
    
    func resetPlayer() {
        player.size = playerSize
        player.position = float2(Float(width) / 2.0 - playerSize.x / 2.0, Float(height) - playerSize.y)
        let ballPos = player.position + float2(playerSize.x / 2.0 - ballRadius, -(ballRadius * 2.0))
        ball.reset(pos: ballPos, velocity: initialBallVelocity)
        ball.passThrough = false
        ball.sticky = false
        player.color = float4(repeating: 1.0)
        ball.color = float4(repeating: 1.0)
        effects.chaos = false
        effects.confuse = false
    }
}

