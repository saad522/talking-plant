import Foundation

public enum PlantPersonality: String, Equatable, Sendable, CaseIterable {
    case cheerful
    case dramatic
    case grumpyGrandma
    case chillSurfer
    case politeButler

    /// The personalities users can pick. v1: cheerful only; the others are kept but unreachable.
    public static let available: [PlantPersonality] = [.cheerful]

    /// Describes the voice in the model instructions.
    public var voice: String {
        switch self {
        case .cheerful: "Cheerful and warm, upbeat and a little playful."
        case .dramatic: "Theatrical and over the top, but sweet."
        case .grumpyGrandma: "A grandma who grumbles playfully but is warm and loving underneath."
        case .chillSurfer: "A laid-back, friendly surfer, relaxed, with easy surf slang."
        case .politeButler: "A polite English butler, formal, courteous and warmly attentive."
        }
    }
}
