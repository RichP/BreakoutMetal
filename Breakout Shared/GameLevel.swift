//
//  GameLevel.swift
//  Breakout
//
//  Created by Richard Pickup on 16/03/2022.
//

import Foundation
import MetalKit

class GameLevel {
    var bricks: [GameObject] = []
    
    func Load(file: String, width: Int, height: Int) {
        bricks = []
        guard let filePath = Bundle.main.url(forResource: file, withExtension: "lvl") else {
            return
        }
        
        var tileData: [[Int]] = []
        do {
            let data = try String(contentsOf: filePath)
            let lines = data.components(separatedBy: .newlines)
            for line in lines {
                let bricks = line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: " ").map {
                        Int($0) ?? 0
                    }
                tileData.append(bricks)
            }
            
        } catch {
            return
        }
        
        buildLevel(tileData: tileData, levelWidth: width, levelHeight: height)
    }
    
    func buildLevel(tileData: [[Int]], levelWidth: Int, levelHeight: Int) {
        let height = tileData.count
        let width = tileData.first?.count ?? 1
        
        let unitWidth = Float(levelWidth) / Float(width)
        let unitHeight = Float(levelHeight) / Float(height)
        
        for (y, row) in tileData.enumerated() {
            for (x, col) in row.enumerated() {
                if col == 1 {
                    let pos = float2( unitWidth * Float(x), unitHeight * Float(y))
                    let size = float2(unitWidth, unitHeight)
                    let obj = GameObject(pos: pos,
                                         size: size,
                                         color: float4(0.8, 0.8, 0.7, 1.0),
                                         spriteFrame: "block_solid.png")
                    obj.isSolid = true
                    bricks.append(obj)
                } else if col > 1 {
                    var color = float4(repeating: 1.0)
                    switch col {
                    case 2:
                        color = float4(0.2, 0.6, 1.0, 1.0)
                    case 3:
                        color = float4(0.0, 0.7, 0.0, 1.0)
                    case 4:
                        color = float4(0.8, 0.8, 0.4, 1.0)
                    case 5:
                        color = float4(1.0, 0.0, 0.0, 1.0)
                    default:
                        color = float4(repeating: 1.0)
                    }
                    let pos = float2( unitWidth * Float(x), unitHeight * Float(y))
                    let size = float2(unitWidth, unitHeight)
                    
                    let obj = GameObject(pos: pos,
                                         size: size,
                                         color: color,
                                         spriteFrame: "block.png")
                    obj.isSolid = false
                    bricks.append(obj)
                    
                }
            }
        }
        
    }
    
    
    func draw(spriteBatch: SpriteBatch) {
        for tile in bricks {
            if !tile.isDestroyed {
                tile.draw(spriteBatch: spriteBatch)
            }
        }
    }
}
