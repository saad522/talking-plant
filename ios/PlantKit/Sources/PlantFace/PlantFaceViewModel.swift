import Foundation
import PlantShared

public enum PlantFaceEyes: Equatable, Sendable {
    case open
    case wide
    case droopy
    case squint
    case closed
}

public final class PlantFaceViewModel {
    public let eyes: PlantFaceEyes
    /// -1 (frown) ... 1 (smile).
    public let mouthCurve: Double
    public let isMouthOpen: Bool
    public let blinks: Bool

    public init(mood: PlantMood) {
        switch mood {
        case .happy:
            (eyes, mouthCurve, isMouthOpen, blinks) = (.open, 1, false, true)
        case .thirsty:
            (eyes, mouthCurve, isMouthOpen, blinks) = (.droopy, -0.4, false, true)
        case .veryThirsty:
            (eyes, mouthCurve, isMouthOpen, blinks) = (.droopy, -1, true, true)
        case .drowning:
            (eyes, mouthCurve, isMouthOpen, blinks) = (.wide, -0.6, true, true)
        case .tooDark:
            (eyes, mouthCurve, isMouthOpen, blinks) = (.wide, -0.2, false, true)
        case .tooHot:
            (eyes, mouthCurve, isMouthOpen, blinks) = (.squint, -0.5, true, true)
        case .tooCold:
            (eyes, mouthCurve, isMouthOpen, blinks) = (.squint, -0.5, false, true)
        case .dryAir:
            (eyes, mouthCurve, isMouthOpen, blinks) = (.open, -0.3, false, true)
        case .offline:
            (eyes, mouthCurve, isMouthOpen, blinks) = (.closed, 0, false, false)
        }
    }
}
