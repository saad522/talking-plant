import Foundation

public struct PlantPersonalityViewModel: Equatable, Sendable {
    public let personality: PlantPersonality
    public let label: String

    public init(personality: PlantPersonality) {
        self.personality = personality
        self.label = switch personality {
        case .cheerful: String.localised(key: "plant.chat.personality.cheerful.label")
        case .dramatic: String.localised(key: "plant.chat.personality.dramatic.label")
        case .grumpyGrandma: String.localised(key: "plant.chat.personality.grumpyGrandma.label")
        case .chillSurfer: String.localised(key: "plant.chat.personality.chillSurfer.label")
        case .politeButler: String.localised(key: "plant.chat.personality.politeButler.label")
        }
    }
}
