//
//  ParticleGenerator.swift
//  Breakout
//
//  Created by Richard Pickup on 19/03/2022.
//

import Foundation

struct Particle {
    var position: float2
    var velocity: float2
    var color: float4
    var life: Float
}

class ParticleGenerator {
    var particles: [Particle] = []
    let amount: Int
    
    var lastUsedPArticle = 0
    
    init(amount: Int) {
        self.amount = amount
        
        particles = [Particle](repeating: Particle(position: float2(repeating: 0.0),
                                                   velocity: float2(repeating: 0.0),
                                                   color: float4(repeating: 1.0),
                                                   life: 0.0), count: amount)
        
        
    }
    
    func firstUnusedParticle() -> Int {
        for i in lastUsedPArticle..<amount {
            if particles[i].life <= 0.0 {
                lastUsedPArticle = i
                return i
            }
        }
        
        for i in 0..<lastUsedPArticle {
            if particles[i].life <= 0.0 {
                lastUsedPArticle = i
                return i
            }
        }
        lastUsedPArticle = 0
        return 0
    }
    
    func respawnParticle(particle: inout Particle, object: GameObject, offset: float2) {
        let random: Float = (Float((arc4random() % 100)) - 50) / 10.0
        let color = 0.5 + (Float(arc4random() % 100) / 100.0)
        particle.position = object.position + random + offset
        particle.color = float4(color, color, color, 1.0)
        particle.life = 1.0
        particle.velocity = object.velocity * 0.1
    }
    
    func update(dt: Float, object: GameObject, newParticles: Int, offset: float2) {
        for _ in 0..<newParticles {
            let unusedParticles = firstUnusedParticle()
            respawnParticle(particle: &particles[unusedParticles],
                            object: object,
                            offset: offset)
        }
        for i in 0..<amount {
            particles[i].life -= dt
            if particles[i].life > 0.0 {
                particles[i].position -= particles[i].velocity * dt
                particles[i].color.w -= dt * 2.5
            }
        }
    }
    
    func draw(spriteBatch: SpriteBatch) {
        particles.forEach { particle in
            if particle.life > 0.0 {
                
                spriteBatch.draw(dst: particle.position,
                                 width: 10.0, height: 10.0,
                                 frameName: "particle.png",
                                 color: particle.color)
            }
        }
    }
    
}
