//
//  FontAtlas.swift
//  Breakout
//
//  Created by Richard Pickup on 25/03/2022.
//

import Foundation

#if os(iOS) || os(tvOS)
import UIKit
typealias Font = UIFont
typealias Image = UIImage
#else
import AppKit
typealias Font = NSFont
typealias Image = NSImage

extension NSImage {
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: .zero)
    }
    
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)
        
        return cgImage(forProposedRect: &proposedRect,
                       context: nil,
                       hints: nil)
    }
}
#endif


struct GlyphDescriptor {
    let glyphIndex: CGGlyph
    let topLeftTexCoord: CGPoint
    let bottomRightTexCoord: CGPoint
    let advance: CGSize
}


class FontAtlas {
    let atlasSize = 2048
    var parentFont: Font
    var fontPointSize: CGFloat
    let spread: CGFloat
    let textureSize: Int
    var glyphDescriptors: [GlyphDescriptor] = []
    
    init(font: Font, textureSize: Int) {
        self.parentFont = font
        self.fontPointSize = font.pointSize
        spread = FontAtlas.estimatedLineWidthForFont(font: font)
        self.textureSize = textureSize
    }
    
//    func stringSize() -> CGSize {
//        
//    }
    
    func descriptorFor(char: Character) -> GlyphDescriptor? {
        var glyph:CGGlyph = 0
        
        let utf16 = Array(char.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
        guard CTFontGetGlyphsForCharacters(parentFont as CTFont, utf16, &glyphs, utf16.count) else {
            return nil
        }
        
        glyph = glyphs.first ?? 0
        
        let filetered = glyphDescriptors.filter { desc in
            desc.glyphIndex == glyph
        }
        
        return filetered.first
    }
    
    static func estimatedLineWidthForFont(font: Font) -> CGFloat {
        let estimatedStrokeWidth: CGFloat = "!".size(withAttributes: [NSAttributedString.Key.font: font]).width
        return estimatedStrokeWidth.rounded(.up)
    }
    
    static func estimatedGlyphSizeForFont(font: Font) -> CGSize {
        let exampleString = "{ǺOJMQYZa@jmqyw"
        let exampleStringSize = exampleString.size(withAttributes: [NSAttributedString.Key.font: font])
        let averageGlyphWidth = (exampleStringSize.width / CGFloat(exampleString.count)).rounded(.up)
        let maxGlyphHeight = exampleStringSize.height.rounded(.up)
        
        return CGSize(width: averageGlyphWidth, height: maxGlyphHeight)
    }
    
    func pointSizeThatFits(font: Font, rect: CGRect) -> CGFloat {
        var fittedSize = font.pointSize
        
        while likelyToFit(font: font, size: fittedSize, rect: rect) {
            fittedSize += 1
        }
        
        while !likelyToFit(font: font, size: fittedSize, rect: rect) {
            fittedSize -= 1
        }
        
        return fittedSize
    }
    
    func likelyToFit(font: Font, size: CGFloat, rect: CGRect) -> Bool {
        let textureArea = rect.size.width * rect.size.height
        let trialFont = Font(name: font.fontName, size: size)!
        let trialCTFont = CTFontCreateWithName(font.fontName as CFString, .zero, nil)
        
        let glyphCount = CTFontGetGlyphCount(trialCTFont)
        let glyphMargin = FontAtlas.estimatedLineWidthForFont(font: trialFont)
        let averageGlyphSize = FontAtlas.estimatedGlyphSizeForFont(font: trialFont)
        let estimatedGlyphArea = (averageGlyphSize.width + glyphMargin) * (averageGlyphSize.height + glyphMargin) * CGFloat(glyphCount)
        
        let fits = estimatedGlyphArea < textureArea
        return fits
    }
    
    func createTextureData() -> Image? {
        return createAtlasForFont(font: parentFont,
                                           width: atlasSize,
                                           height: atlasSize)
    }
    
    func createAtlasForFont(font: Font, width: Int, height: Int) -> Image? {
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        let count = bytesPerRow * height
        
        let bitmapInfo = CGBitmapInfo(rawValue:  CGImageAlphaInfo.premultipliedLast.rawValue)
        
        let mutBufPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        let context = CGContext(data: mutBufPtr,
                                           width: width,
                                           height: height,
                                           bitsPerComponent: 8,
                                           bytesPerRow: bytesPerRow,
                                           space: colorSpace,
                                           bitmapInfo: bitmapInfo.rawValue)
        
        context?.setAllowsAntialiasing(false)
        
        context?.translateBy(x: 0, y: 0)
        context?.scaleBy(x: 1, y: 1)
        
        context?.setFillColor(red: 0, green: 0, blue: 0, alpha: 0)
        context?.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        fontPointSize = pointSizeThatFits(font: font,
                                               rect: CGRect(x: 0, y: 0, width: width, height: height))
        
        let ctFont = CTFontCreateWithName(font.fontName as CFString, self.fontPointSize, nil)
        parentFont = Font(name: font.fontName, size: fontPointSize)!
        
        let glyphCount = CTFontGetGlyphCount(ctFont)
        
        let glyphMargin = FontAtlas.estimatedLineWidthForFont(font: parentFont)
        
        context?.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        glyphDescriptors = []
        
        let fontAscent = CTFontGetAscent(ctFont)
        let fontDescent = CTFontGetDescent(ctFont)
        
        var origin = CGPoint(x: 0, y: fontAscent)
        var maxYForLine: CGFloat = -1
        
        for i in 0..<glyphCount {
            var glyph = CGGlyph(i)
            var boundingRect: CGRect = .zero
            var advance: CGSize = .zero
            CTFontGetBoundingRectsForGlyphs(ctFont, .horizontal, &glyph, &boundingRect, 1)
            
            CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyph, &advance, 1)

            if origin.x + boundingRect.maxX + glyphMargin > CGFloat(width) {
                origin.x = 0
                origin.y = maxYForLine + glyphMargin + fontDescent
                maxYForLine = -1
            }
            
            if origin.y + boundingRect.maxY > maxYForLine {
                maxYForLine = origin.y + boundingRect.maxY
            }
            
            let glyphOriginX = origin.x - boundingRect.minX + (glyphMargin * 0.5)
            let glyphOriginY = origin.y + (glyphMargin * 0.5)
            
            var transform = __CGAffineTransformMake(1, 0, 0, -1, glyphOriginX, glyphOriginY)
            
            var pathBoundingRect: CGRect = .zero
            if let path = CTFontCreatePathForGlyph(ctFont, glyph, &transform) {
                context?.addPath(path)
                context?.fillPath()
                
                pathBoundingRect = path.boundingBoxOfPath
            }
            
            // convert null rect to zero
            if pathBoundingRect.equalTo(CGRect.null) {
                pathBoundingRect = .zero
            }
            
            let descriptor = GlyphDescriptor(glyphIndex: glyph,
                                             topLeftTexCoord: pathBoundingRect.origin,
                                             bottomRightTexCoord: CGPoint(x: pathBoundingRect.width,
                                                                          y: pathBoundingRect.height),
                                             advance: advance)
            
            glyphDescriptors.append(descriptor)
            
            origin.x += boundingRect.width + glyphMargin
            
        }
        
        if let contextImage = context?.makeImage() {
            let fontImage = Image(cgImage: contextImage)
            
            return fontImage
        }
        return nil
    }
}

