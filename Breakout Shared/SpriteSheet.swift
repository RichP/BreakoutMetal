//
//  SpriteSheet.swift
//  Breakout
//
//  Created by Richard Pickup on 23/03/2022.
//

import Foundation

struct SheetData: Codable {
    let frames: [FrameElement]
    let meta: Meta
}

// MARK: - FrameElement
struct FrameElement: Codable {
    let filename: String
    let frame: SpriteSourceSizeClass
    let rotated, trimmed: Bool
    let spriteSourceSize: SpriteSourceSizeClass
    let sourceSize: Size
}

// MARK: - SpriteSourceSizeClass
struct SpriteSourceSizeClass: Codable {
    let x, y, w, h: Int
}

// MARK: - Size
struct Size: Codable {
    let w, h: Int
}

// MARK: - Meta
struct Meta: Codable {
    let app: String
    let version, image, format: String
    let size: Size
    let scale: String
}

class SpriteSheet {
    
    var sheetData: SheetData!
    
    init(name: String) {
        readJson(name: name)
    }
    
    func readJson(name: String) {
        guard let path = Bundle.main.path(forResource: name, ofType: "json"),
        let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)else {
            return
        }
        
        let sheet = try? JSONDecoder().decode(SheetData.self, from: data)
        
        sheetData = sheet
    }
    
    func frame(name: String) -> Rectangle {
        guard let frame = sheetData.frames.filter({ frame in
            frame.filename == name
        }).first else {
            let metaSize = sheetData.meta.size
            let rect = Rectangle(left: 0.0, right: Float(metaSize.w), top: 0.0, bottom: Float(metaSize.h))
            return rect
        }
        
        let rectFrame = frame.frame
        
        let rect = Rectangle(left: Float(rectFrame.x),
                             right: Float(rectFrame.w),
                             top: Float(rectFrame.y),
                             bottom: Float(rectFrame.h))
        
        return rect
    }
}
