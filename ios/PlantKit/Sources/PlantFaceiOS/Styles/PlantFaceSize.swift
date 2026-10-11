import PlantFace
import SwiftUI

enum PlantFaceSize {
    static let face: CGFloat = 160
    static let eyeWidth: CGFloat = 24
    static let eyeHeight: CGFloat = 32
    /// Fixed slot so eyes stay centred while their height changes.
    static let eyeSlotHeight: CGFloat = 48
    static let eyeSpacing: CGFloat = 44
    static let eyesOffset: CGFloat = -16
    static let mouthWidth: CGFloat = 64
    static let mouthHeight: CGFloat = 28
    static let mouthOffset: CGFloat = 36
    static let breathingScale: CGFloat = 1.03

    /// Share of `eyeHeight` each expression shows.
    static func eyeHeightRatio(for eyes: PlantFaceEyes) -> CGFloat {
        switch eyes {
        case .open: 1
        case .wide: 1.3
        case .droopy: 0.5
        case .squint: 0.25
        case .closed: 0.08
        }
    }

    static let blinkHeightRatio: CGFloat = 0.08
}
