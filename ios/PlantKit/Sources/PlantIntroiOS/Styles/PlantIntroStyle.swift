import SwiftUI

enum PlantIntroSize {
    static let glowDiameter: CGFloat = 320
    static let titleGap: CGFloat = 20
    static let textRise: CGFloat = 16
    static let textSpacing: CGFloat = 6
    /// Home puts Sprout a bit above the screen centre and a bit smaller.
    static let handoffOffsetY: CGFloat = -70
    static let handoffScale: CGFloat = 0.8
}

enum PlantIntroColor {
    static let title = Color(red: 0xEE / 255, green: 0xF2 / 255, blue: 0xF6 / 255)
    static let greeting = Color(red: 0xA9 / 255, green: 0xB6 / 255, blue: 0xC6 / 255)
    static let firefly = Color(red: 0xFF / 255, green: 0xD6 / 255, blue: 0x6B / 255)
    static let pollen = Color(red: 0xCF / 255, green: 0xE8 / 255, blue: 0xB5 / 255)
    static let fireflyGlow = Color(red: 0xFF / 255, green: 0xD6 / 255, blue: 0x6B / 255)
    static let pollenGlow = Color(red: 0x7B / 255, green: 0xD3 / 255, blue: 0x9A / 255)
}
