//
//  Ball.swift
//  Breakout
//
//  Created by Richard Pickup on 19/03/2022.
//

import Foundation


class Ball: GameObject {
    let radius: Float
    var stuck: Bool = true
    var sticky: Bool = false
    var passThrough: Bool = false
    
    init(pos: float2,
         radius: Float,
         velocity: float2 = float2(0,0), spriteFrame: String) {
        self.radius = radius
        super.init(pos: pos,
                   size: float2(radius * 2.0, radius * 2.0),
                   velocity: velocity,
                   spriteFrame: spriteFrame)
    }
    
    func move(dt: Float, width: Int) -> float2 {
        guard !stuck else {
            return position
        }
        position += velocity * dt
        
        if position.x <= 0.0 {
            velocity.x = -velocity.x
            position.x = 0.0
        } else if position.x + size.x >= Float(width) {
            velocity.x = -velocity.x
            position.x = Float(width) - size.x
        }
        
        if position.y <= 0.0 {
            velocity.y = -velocity.y
            position.y = 0.0
        }
        
        return position
    }
    
    func reset(pos: float2, velocity: float2) {
        stuck = true
        position = pos
        self.velocity = velocity
    }
}
