import Foundation
import PlantShared

public final class PlantMoodViewModel {
    public let label: String

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
    }
}
