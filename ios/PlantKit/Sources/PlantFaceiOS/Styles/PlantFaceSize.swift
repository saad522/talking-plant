import SwiftUI

enum PlantFaceSize {
    /// The drawing is laid out in this viewBox, then scaled uniformly to `face`.
    static let viewBox = CGSize(width: 240, height: 280)
    static let face = CGSize(width: 270, height: 315)
    static let faceScale: CGFloat = face.width / viewBox.width

    static let headCenter = CGPoint(x: 120, y: 128)
    static let headRadius: CGFloat = 56
    /// The head group tilts and breathes around the base of the stem.
    static let headPivot = UnitPoint(x: 120 / viewBox.width, y: 206 / viewBox.height)
    static let armOrigin = CGPoint(x: 120, y: 192)
    static let topLeafX: CGFloat = 120

    static let eyeRx: CGFloat = 7
    static let blinkRy: CGFloat = 1
    static let breathingScale: CGFloat = 1
    static let breathingScaleIn: CGFloat = 1.02
    static let swayDegrees: Double = 3
    static let dropSize = CGSize(width: 10, height: 14)
}
