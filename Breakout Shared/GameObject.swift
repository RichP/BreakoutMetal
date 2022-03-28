//
//  GameObject.swift
//  Breakout
//
//  Created by Richard Pickup on 16/03/2022.
//

import Foundation


class GameObject {
    var position: float2
    var size: float2
    var velocity: float2
    var color: float4
    let rotation: Float = 0.0
    var isSolid: Bool = true
    var isDestroyed: Bool = false
    var spriteFrame: String
    
    init(pos: float2 = float2(0.0, 0.0),
         size: float2 = float2(1.0, 1.0),
         color: float4 = float4(1.0, 1.0, 1.0, 1.0),
         velocity: float2 = float2(0,0),
         spriteFrame: String) {
        self.position = pos
        self.size = size
        self.color = color
        self.velocity = velocity
        self.spriteFrame = spriteFrame
    }
    
    func draw(spriteBatch: SpriteBatch) {
        spriteBatch.draw(dst: position,
                         width: size.x,
                         height: size.y,
                         frameName: spriteFrame,
                         color: color)
        
    }
}
