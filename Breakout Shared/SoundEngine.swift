//
//  SoundEngine.swift
//  Breakout
//
//  Created by Richard Pickup on 28/03/2022.
//

import Foundation
import AVFoundation

class SoundEngine {
    
    var sounds: [String: AVAudioPlayer] = [:]
    
    func play2D(file: String, loop: Bool) {
        var effect: AVAudioPlayer?
        if let audio = sounds[file] {
            effect = audio
        } else {
            print("loading sound")
            let path = Bundle.main.path(forResource: file, ofType: nil) ?? ""
            let url = URL(fileURLWithPath: path)
            do {
                effect = try AVAudioPlayer(contentsOf: url)
            } catch {
                print("couldn't load \(file)")
            }
        }
        
        if let effect = effect {
            effect.stop()
            effect.numberOfLoops = loop ? -1 : 1
            effect.play()
            sounds[file] = effect
        } 
    }
    
}
