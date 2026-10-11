import Foundation
import PlantShared

public struct PlantChatMoodViewModel: Equatable, Sendable {
    public let mood: PlantMood
    public let label: String

    public init(mood: PlantMood) {
        self.mood = mood
        self.label = switch mood {
        case .happy: String.localised(key: "plant.chat.mood.happy.label")
        case .thirsty: String.localised(key: "plant.chat.mood.thirsty.label")
        case .veryThirsty: String.localised(key: "plant.chat.mood.veryThirsty.label")
        case .drowning: String.localised(key: "plant.chat.mood.drowning.label")
        case .tooDark: String.localised(key: "plant.chat.mood.tooDark.label")
        case .tooHot: String.localised(key: "plant.chat.mood.tooHot.label")
        case .tooCold: String.localised(key: "plant.chat.mood.tooCold.label")
        case .dryAir: String.localised(key: "plant.chat.mood.dryAir.label")
        case .offline: String.localised(key: "plant.chat.mood.offline.label")
        }
    }
}
