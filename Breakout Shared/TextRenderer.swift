//
//  TextRenderer.swift
//  Breakout
//
//  Created by Richard Pickup on 26/03/2022.
//

import Foundation
import MetalKit

class TextRenderer {
    let fontAtlas: FontAtlas
    let image: Image?
    
    var spriteBatch: SpriteBatch?
    
    init(font: Font) {
        fontAtlas = FontAtlas(font: font, textureSize: 4096)
        
        image = fontAtlas.createTextureData()
    }
    
    func measureString(_ text: String) -> float2 {
        var posX: Float = 0.0
        var widthToAdd: Float = 0.0
        for char in text {
            guard let glyphDescriptor = fontAtlas.descriptorFor(char: char) else {
                continue
            }
            posX += Float(glyphDescriptor.advance.width)
            
            widthToAdd = Float(glyphDescriptor.bottomRightTexCoord.x)
        }
        //add last char width
        posX += widthToAdd
        return float2(posX, 1.0)
    }
    
    func createTexture(device: MTLDevice) {
        
        let cgimage = image?.cgImage
        
        let textureLoader = MTKTextureLoader(device: device)
        
        guard let cgimage = cgimage else { return }
        
        textureLoader.newTexture(cgImage: cgimage,
                                 options: nil) { tex, error in
            
            if let tex = tex {
                self.spriteBatch = SpriteBatch(spriteTexture: tex, sheetName: nil)
            }
        }
    }
    
    func start(uniforms: Uniforms, renderEncoder: MTLRenderCommandEncoder?) {
        spriteBatch?.start(uniforms: uniforms,
                           renderEncoder: renderEncoder)
    }
    
    func end() {
        spriteBatch?.end()
    }
    
    func renderText(text: String, x: Float, y: Float, scale: Float, color: float4, uniforms: Uniforms, renderEncoder: MTLRenderCommandEncoder?) {
        
        var posX = x
        for char in text {
            
            guard let glyphDescriptor = fontAtlas.descriptorFor(char: char),
                  let heightDescriptor = fontAtlas.descriptorFor(char: "H") else {
                continue
            }
            
            let src = Rectangle(left: Float(glyphDescriptor.topLeftTexCoord.x),
                                right: Float(glyphDescriptor.bottomRightTexCoord.x),
                                top: Float(glyphDescriptor.topLeftTexCoord.y),
                                bottom: Float(glyphDescriptor.bottomRightTexCoord.y))
            
            let chHeight = Float(src.bottom) * scale
            let hHeight = Float(heightDescriptor.bottomRightTexCoord.y)
            
            let posY = y + ( hHeight - chHeight)
            
            let chWidth = src.right * scale
            
            let dest = Rectangle(left: posX, right: chWidth, top: posY, bottom: chHeight)
            
            spriteBatch?.draw(dest: dest,
                              src: src,
                              color: color)
            
            
            posX += Float(glyphDescriptor.advance.width) * scale
        }
    }
}
