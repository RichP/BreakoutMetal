//
//  Game.swift
//  Breakout
//
//  Created by Richard Pickup on 15/03/2022.
//

import Foundation
import GameController

enum GameState {
    case active
    case menu
    case win
}

enum Direction: Int {
    case up
    case right
    case down
    case left
    
    static func vectorDirection(target: float2) -> Direction {
        let compass = [
            float2(0.0, 1.0),
            float2(1.0, 0.0),
            float2(0.0, -1.0),
            float2(-1.0, 0.0),
        ]
        var max: Float = 0.0
        var bestMatch = -1
        for i in 0..<4 {
            let dp = dot(normalize(target), compass[i])
            if dp > max {
                max = dp
                bestMatch = i
            }
        }
        
        return Direction(rawValue: bestMatch) ?? .up
    }
}

typealias Collision = (Bool, Direction, float2)

class Game {
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
    var shake: Bool = false
    
    var chaos: Bool = false
    var confuse: Bool = false
    
    
    
    init(width: Int, height: Int, device: MTLDevice) {
        self.width = width
        self.height = height
        
        let font = Font.systemFont(ofSize: 24)
        
        textRenderer = TextRenderer(font: font)
        textRenderer.createTexture(device: Renderer.device)
        
        self.background = try? Renderer.loadTexture(device: device, imageName: "background.jpg")
        
        self.sprites = try? Renderer.loadTexture(device: device, imageName: "spritesheet")
        
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
                chaos = false
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
                shake = false
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
    
    func render(device: MTLDevice, uniforms: Uniforms, renderEncoder: MTLRenderCommandEncoder?) {
        
        textRenderer.start(uniforms: uniforms, renderEncoder: renderEncoder)
        
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
    func doCollisions() {
        for box in levels[level].bricks {
            if !box.isDestroyed {
                
                let collision = checkCollision(one: ball, two: box)
                if collision.0 {
                    if !box.isSolid {
                        box.isDestroyed = true
                        spawnPowerUps(block: box)
                        soundEngine.play2D(file: "audio/bleep.mp3", loop: false)
                    } else {
                        shakeTime = 0.05
                        shake = true
                        soundEngine.play2D(file: "audio/solid.wav", loop: false)
                    }
                    
                    let direction = collision.1
                    let diff = collision.2
                    if !(ball.passThrough && !box.isSolid) {
                        if direction == .left || direction == .right {
                            ball.velocity.x = -ball.velocity.x
                            let penetration = ball.radius - abs(diff.x)
                            ball.position.x += direction == .left ? penetration : -penetration
                        } else {
                            ball.velocity.y = -ball.velocity.y
                            let penetration = ball.radius - abs(diff.y)
                            ball.position.y += direction == .up ? -penetration : penetration
                        }
                    }
                }
            }
        }
        
        powerUps.forEach { powerUp in
            if !powerUp.isDestroyed {
                if powerUp.position.y >= Float(height) {
                    powerUp.isDestroyed = true
                }
                if checkCollision(one: player, two: powerUp) {
                    activatePowerUp(powerUp)
                    powerUp.isDestroyed = true
                    powerUp.activated = true
                    soundEngine.play2D(file: "audio/powerup.wav", loop: false)
                }
            }
        }
        
        let result = checkCollision(one: ball, two: player)
        if !ball.stuck && result.0 {
            let centreBoard = player.position.x + player.size.x / 2.0
            let distance = (ball.position.x + ball.radius) - centreBoard
            let percentage = distance / (playerSize.x / 2.0)
            
            let strength: Float = 2.0
            let oldVelocity = ball.velocity
            ball.velocity.x = initialBallVelocity.x * percentage * strength
            ball.velocity.y = -ball.velocity.y
            ball.velocity.y = -1.0 * abs(ball.velocity.y)
            ball.velocity = normalize(ball.velocity) * length(oldVelocity)
            
            ball.stuck = ball.sticky
            
            soundEngine.play2D(file: "audio/bleep.wav", loop: false)
        }
    }
    func checkCollision(one: GameObject, two: GameObject) -> Bool {
        let collisionX = one.position.x + one.size.x >= two.position.x &&
        two.position.x + two.size.x >= one.position.x
        
        let collisionY = one.position.y + one.size.y >= two.position.y && two.position.y + two.size.y >= one.position.y
        
        return collisionX && collisionY
        
    }
    
    func checkCollision(one: Ball, two: GameObject) -> Collision {
        let centre = one.position + one.radius
        let aabbHalfExtent = float2(two.size.x / 2.0, two.size.y / 2.0)
        let aabbCentre = float2(two.position.x + aabbHalfExtent.x,
                                two.position.y + aabbHalfExtent.y)
        
        var difference = centre - aabbCentre
        let clamped = difference.clamped(lowerBound: -aabbHalfExtent, upperBound: aabbHalfExtent)
        let closest = aabbCentre + clamped
        difference = closest - centre
        let len = length(difference)
        if  len < one.radius {
            return Collision(true, Direction.vectorDirection(target: difference), difference)
        }
        
        return Collision(false, .up, difference)
    }
    
    func clamp(value: Float, min: Float, max: Float) -> Float {
        return Float.maximum(min, Float.minimum(max,value))
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
        chaos = false
        confuse = false
    }
}


extension Game {
    func spawnPowerUps(block: GameObject) {
        if shouldSpawn(chance: 75) {
            powerUps.append(PowerUp(type: .speed,
                                    color: float4(0.5, 0.5, 1.0, 1.0),
                                    duration: 0.0,
                                    position: block.position))
        }
        
        if shouldSpawn(chance: 75) {
            powerUps.append(PowerUp(type: .sticky,
                                    color: float4(1.0, 0.5, 1.0, 1.0),
                                    duration: 2.0,
                                    position: block.position))
        }
        
        if shouldSpawn(chance: 75) {
            powerUps.append(PowerUp(type: .passThrough,
                                    color: float4(0.5, 1.0, 0.5, 1.0),
                                    duration: 10.0,
                                    position: block.position))
        }
        
        if shouldSpawn(chance: 75) {
            powerUps.append(PowerUp(type: .padSizeIncrease,
                                    color: float4(1.0, 0.6, 0.4, 1.0),
                                    duration: 0.0,
                                    position: block.position))
        }
        
        if shouldSpawn(chance: 15) {
            powerUps.append(PowerUp(type: .confuse,
                                    color: float4(1.0, 0.3, 0.3, 1.0),
                                    duration: 15.0,
                                    position: block.position))
        }
        
        if shouldSpawn(chance: 15) {
            powerUps.append(PowerUp(type: .chaos,
                                    color: float4(0.9, 0.25, 0.25, 1.0),
                                    duration: 15.0,
                                    position: block.position))
        }
    }
    
    func updatePowerUps(dt: Float) {
        powerUps.forEach { powerUp in
            powerUp.position += powerUp.velocity * dt
            if powerUp.activated {
                powerUp.duration -= dt
                if powerUp.duration <= 0.0 {
                    powerUp.activated = false
                    switch powerUp.type {
                    case .sticky:
                        if !isOtherPowerUpActive(type: .sticky) {
                            ball.sticky = false
                            player.color = float4(repeating: 1.0)
                        }
                    case .passThrough:
                        if !isOtherPowerUpActive(type: .passThrough) {
                            ball.passThrough = false
                            player.color = float4(repeating: 1.0)
                        }
                    case .confuse:
                        if !isOtherPowerUpActive(type: .confuse) {
                            confuse = false
                        }
                    case .chaos:
                        if !isOtherPowerUpActive(type: .chaos) {
                            chaos = false
                        }
                    default:
                        return
                    }
                }
            }
        }
        
        powerUps.removeAll { powerUp in
            powerUp.isDestroyed && !powerUp.activated
        }
    }
    
    func isOtherPowerUpActive(type: PowerUpType) -> Bool {
        for powerUp in powerUps {
            if powerUp.activated, powerUp.type == type {
                return true
            }
        }
        return false
    }
    
    func activatePowerUp(_ powerUP: PowerUp) {
        switch powerUP.type {
        case .speed:
            ball.velocity *= 1.2
        case .sticky:
            ball.sticky = true
            player.color = float4(1.0, 0.5, 1.0, 1.0)
        case .passThrough:
            ball.passThrough = true
            ball.color = float4(1.0, 0.5, 0.5, 1.0)
        case .padSizeIncrease:
            player.size.x += 50
        case .confuse:
            confuse = true
        case .chaos:
            chaos = true
        }
    }
    
    func shouldSpawn(chance: UInt32) -> Bool {
        let random = arc4random() % chance
        return random == 0
    }
}


