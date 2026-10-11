import Foundation
import PlantShared

public final class PlantMoodViewModel {
    public let label: String
    /// A template line in the plant's voice, until the real Talk feature.
    public let speech: String

    public init(mood: PlantMood) {
        self.label = switch mood {
        case .happy: String.localised(key: "plant.monitor.mood.happy.label")
        case .thirsty: String.localised(key: "plant.monitor.mood.thirsty.label")
        case .veryThirsty: String.localised(key: "plant.monitor.mood.veryThirsty.label")
        case .drowning: String.localised(key: "plant.monitor.mood.drowning.label")
        case .tooDark: String.localised(key: "plant.monitor.mood.tooDark.label")
        case .tooHot: String.localised(key: "plant.monitor.mood.tooHot.label")
        case .tooCold: String.localised(key: "plant.monitor.mood.tooCold.label")
        case .dryAir: String.localised(key: "plant.monitor.mood.dryAir.label")
        case .offline: String.localised(key: "plant.monitor.mood.offline.label")
        }
        self.speech = switch mood {
        case .happy: String.localised(key: "plant.monitor.mood.happy.speech")
        case .thirsty: String.localised(key: "plant.monitor.mood.thirsty.speech")
        case .veryThirsty: String.localised(key: "plant.monitor.mood.veryThirsty.speech")
        case .drowning: String.localised(key: "plant.monitor.mood.drowning.speech")
        case .tooDark: String.localised(key: "plant.monitor.mood.tooDark.speech")
        case .tooHot: String.localised(key: "plant.monitor.mood.tooHot.speech")
        case .tooCold: String.localised(key: "plant.monitor.mood.tooCold.speech")
        case .dryAir: String.localised(key: "plant.monitor.mood.dryAir.speech")
        case .offline: String.localised(key: "plant.monitor.mood.offline.speech")
        }
    }
}
