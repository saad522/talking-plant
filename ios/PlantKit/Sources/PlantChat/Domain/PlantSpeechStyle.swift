import PlantShared

public struct PlantSpeechStyle: Equatable, Sendable {
    public static let speedRange: ClosedRange<Float> = 0.5...2
    public static let rateRange: ClosedRange<Float> = 0...1

    public let language: String
    /// On `AVSpeechUtterance`'s 0–1 scale, where 0.5 is normal speed. How fast the voice itself talks.
    public let rate: Float
    /// Speed of the Kokoro voice, where 1 is the voice's normal speed.
    public let speed: Float
    /// Used when installed, otherwise the best voice for `language`.
    public let preferredVoiceIdentifier: String?

    public init(
        language: String,
        rate: Float,
        speed: Float,
        preferredVoiceIdentifier: String? = nil
    ) {
        self.language = language
        self.rate = rate
        self.speed = speed
        self.preferredVoiceIdentifier = preferredVoiceIdentifier
    }

    /// The style for a mood: speed multiplied, everything clamped to its range.
    public func adjusted(for mood: PlantMood?) -> PlantSpeechStyle {
        let speedFactor: Float = switch mood {
        case .happy: 1.05
        case .thirsty, .veryThirsty, .tooHot, .tooCold: 0.92
        case .drowning: 0.90
        case .tooDark, .dryAir, .offline, nil: 1
        }
        return PlantSpeechStyle(
            language: language,
            rate: rate.clamped(to: Self.rateRange),
            speed: (speed * speedFactor).clamped(to: Self.speedRange),
            preferredVoiceIdentifier: preferredVoiceIdentifier
        )
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension PlantPersonality {
    public var speechStyle: PlantSpeechStyle {
        switch self {
        case .cheerful: PlantSpeechStyle(language: "en-US", rate: 0.50, speed: 1.00)
        case .dramatic: PlantSpeechStyle(language: "en-US", rate: 0.46, speed: 0.95)
        case .grumpyGrandma: PlantSpeechStyle(language: "en-IE", rate: 0.42, speed: 0.95)
        case .chillSurfer: PlantSpeechStyle(language: "en-AU", rate: 0.46, speed: 0.90)
        case .politeButler: PlantSpeechStyle(language: "en-GB", rate: 0.48, speed: 1.00)
        }
    }
}
