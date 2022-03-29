//
//  Game+Powerups.swift
//  Breakout
//
//  Created by Richard Pickup on 29/03/2022.
//

import Foundation


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
                            effects.confuse = false
                        }
                    case .chaos:
                        if !isOtherPowerUpActive(type: .chaos) {
                            effects.chaos = false
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
            effects.confuse = true
        case .chaos:
            effects.chaos = true
        }
    }
    
    func shouldSpawn(chance: UInt32) -> Bool {
        let random = arc4random() % chance
        return random == 0
    }
}
