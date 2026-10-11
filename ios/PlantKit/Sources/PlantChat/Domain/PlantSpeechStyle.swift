public struct PlantSpeechStyle: Equatable, Sendable {
    public let language: String
    /// On `AVSpeechUtterance`'s 0–1 scale, where 0.5 is normal speed.
    public let rate: Float
    /// A multiplier, 0.5–2.
    public let pitch: Float

    public init(language: String, rate: Float, pitch: Float) {
        self.language = language
        self.rate = rate
        self.pitch = pitch
    }
}

extension PlantPersonality {
    public var speechStyle: PlantSpeechStyle {
        switch self {
        case .cheerful: PlantSpeechStyle(language: "en-US", rate: 0.52, pitch: 1.15)
        case .dramatic: PlantSpeechStyle(language: "en-US", rate: 0.46, pitch: 1.25)
        case .grumpyGrandma: PlantSpeechStyle(language: "en-IE", rate: 0.42, pitch: 0.90)
        case .chillSurfer: PlantSpeechStyle(language: "en-AU", rate: 0.44, pitch: 0.95)
        case .politeButler: PlantSpeechStyle(language: "en-GB", rate: 0.48, pitch: 0.90)
        }
    }
}
