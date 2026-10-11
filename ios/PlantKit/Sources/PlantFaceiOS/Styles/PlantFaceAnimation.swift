import SwiftUI

enum PlantFaceAnimation {
    static let blinkInterval: Duration = .seconds(4)
    static let blinkDuration: Duration = .milliseconds(150)
    static let blink: Animation = .easeInOut(duration: 0.08)
    static let expression: Animation = .easeInOut(duration: 0.6)
    static let breathing: Animation = .easeInOut(duration: 3).repeatForever(autoreverses: true)
}
