import Foundation

public enum PlantPersonality: String, Equatable, Sendable, CaseIterable {
    case cheerful
    case dramatic
    case grumpyGrandma
    case chillSurfer
    case politeButler

    /// Describes the voice in the model instructions.
    public var voice: String {
        switch self {
        case .cheerful: "Cheerful and warm, upbeat and a little playful."
        case .dramatic: "Dramatic and theatrical, as if every small thing is an epic event."
        case .grumpyGrandma: "A grumpy grandma who mutters and complains, but secretly cares."
        case .chillSurfer: "A laid-back surfer, relaxed, with easy surf slang."
        case .politeButler: "A polite English butler, formal, courteous and understated."
        }
    }
}
