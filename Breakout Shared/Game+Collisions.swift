//
//  Game+Collisions.swift
//  Breakout
//
//  Created by Richard Pickup on 29/03/2022.
//

import Foundation

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
                        effects.shake = true
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
