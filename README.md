# Breakout writain in Swift using Metal

This is a port of the Breakout game in [Joey de Vris](http://joeydevries.com/#home) [LearnOpenGL](https://learnopengl.com) site. Ported to Swift and rendered using Metal

## Changes from original

- Rewriten in Swift using Metal

- Supports MacOS, AppleTV and iOS and uses the Game Controller Keyboard (Currently iOS requires Bluetooth Keyboard as no touch controls added)

- Sprites converted to a Spritesheet using TexturePacker and rendered using a Sprite Batcher

- Text glyphs and font image are generated using Core Text rather than FreeType

- Audio is played (badly) using AVAudioPlayer instead of Irrklang

