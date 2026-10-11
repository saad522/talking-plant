import Foundation

public struct PlantVoiceLineRequest: Equatable, Sendable {
    public enum Purpose: Equatable, Sendable {
        case home
        case notification
        case greeting
    }

    public let facts: PlantVoiceFacts
    public let purpose: Purpose

    public init(facts: PlantVoiceFacts, purpose: Purpose) {
        self.facts = facts
        self.purpose = purpose
    }
}
