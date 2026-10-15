import Foundation
import PlantShared

public enum PlantFaceState: Equatable, Hashable, Sendable {
    case happy
    case thirsty
    case hot
    case cold
    case asleep
    case overwatered
}

public final class PlantFaceViewModel {
    public let state: PlantFaceState
    /// Dry soil color and pot cracks. Only a watering problem, so dry air doesn't set it.
    public let drySoil: Bool
    /// Degrees added to the pose's tilt.
    public let extraTilt: Double
    /// True when the eyes are open, so there is something to blink.
    public let blinks: Bool
    /// A startled reaction (a shake): wide eyes and an "o" mouth on top of the mood's look.
    public let isSurprised: Bool

    public init(mood: PlantMood, isSurprised: Bool = false) {
        self.isSurprised = isSurprised
        switch mood {
        case .happy: state = .happy
        case .thirsty, .veryThirsty, .dryAir: state = .thirsty
        case .tooHot: state = .hot
        case .tooCold: state = .cold
        case .tooDark, .offline: state = .asleep
        case .drowning: state = .overwatered
        }
        drySoil = mood == .thirsty || mood == .veryThirsty
        extraTilt = mood == .veryThirsty ? 6 : 0
        blinks = !isSurprised && (state == .happy || state == .thirsty || state == .overwatered)
    }
}
