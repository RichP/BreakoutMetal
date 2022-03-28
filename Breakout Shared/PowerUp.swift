//
//  PowerUp.swift
//  Breakout
//
//  Created by Richard Pickup on 24/03/2022.
//

import Foundation

enum PowerUpType {
    case speed
    case sticky
    case passThrough
    case padSizeIncrease
    case confuse
    case chaos
    
    func spriteFrame() -> String {
        switch self {
        case .speed:
            return "powerup_speed.png"
        case .sticky:
            return "powerup_sticky.png"
        case .passThrough:
            return "powerup_passthrough.png"
        case .padSizeIncrease:
            return "powerup_increase.png"
        case .confuse:
            return "powerup_confuse.png"
        case .chaos:
            return "powerup_chaos.png"
        }
    }
}

class PowerUp: GameObject {
    let type: PowerUpType
    var duration: Float
    var activated: Bool
    
    let powerSize = float2(60.0, 20.0)
    let powerVelocity = float2(0.0, 150.0)
    
    init(type: PowerUpType, color: float4, duration: Float, position: float2) {
        self.type = type
        self.duration = duration
        self.activated = false
        super.init(pos: position,
                   size: powerSize,
                   color: color,
                   velocity: powerVelocity,
                   spriteFrame: type.spriteFrame())
    }
}
