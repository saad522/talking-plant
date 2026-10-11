import SwiftUI

enum PlantFaceAnimation {
    static let blinkInterval: ClosedRange<Double> = 3...6
    static let blinkDuration: Duration = .milliseconds(150)
    static let blink: Animation = .easeInOut(duration: 0.08)
    static let morph: Animation = .spring(duration: 0.6, bounce: 0.2)
    static let crossFade: Animation = .easeInOut(duration: 0.3)
    static let breathing: Animation = .easeInOut(duration: 3).repeatForever(autoreverses: true)
    static let sway: Animation = .easeInOut(duration: 2.5).repeatForever(autoreverses: true)
}
