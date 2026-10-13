import PlantShared

public struct PlantSpeechStyle: Equatable, Sendable {
    public static let pitchCentsRange: ClosedRange<Float> = -1200...1200
    public static let effectRateRange: ClosedRange<Float> = 0.5...2
    public static let wobbleCentsRange: ClosedRange<Float> = 0...200
    public static let rateRange: ClosedRange<Float> = 0...1

    public let language: String
    /// On `AVSpeechUtterance`'s 0–1 scale, where 0.5 is normal speed. How fast the voice itself talks.
    public let rate: Float
    /// Pitch shift of the effect, in cents (100 = one semitone).
    public let pitchCents: Float
    /// Playback speed of the effect, where 1 is unchanged.
    public let effectRate: Float
    /// Depth of a slow pitch wobble, in cents. 0 is none.
    public let wobbleCents: Float
    /// Used when installed, otherwise the best voice for `language`.
    public let preferredVoiceIdentifier: String?

    public init(
        language: String,
        rate: Float,
        pitchCents: Float,
        effectRate: Float,
        wobbleCents: Float = 0,
        preferredVoiceIdentifier: String? = nil
    ) {
        self.language = language
        self.rate = rate
        self.pitchCents = pitchCents
        self.effectRate = effectRate
        self.wobbleCents = wobbleCents
        self.preferredVoiceIdentifier = preferredVoiceIdentifier
    }

    /// The style for a mood: pitch added, rates multiplied, everything clamped to its range.
    public func adjusted(for mood: PlantMood?) -> PlantSpeechStyle {
        let (pitchOffset, rateFactor, wobble): (Float, Float, Float) = switch mood {
        case .happy: (100, 1.05, 0)
        case .thirsty, .veryThirsty, .tooHot, .tooCold: (-100, 0.92, 0)
        case .drowning: (0, 0.90, 60)
        case .tooDark, .dryAir, .offline, nil: (0, 1, 0)
        }
        return PlantSpeechStyle(
            language: language,
            rate: rate.clamped(to: Self.rateRange),
            pitchCents: (pitchCents + pitchOffset).clamped(to: Self.pitchCentsRange),
            effectRate: (effectRate * rateFactor).clamped(to: Self.effectRateRange),
            wobbleCents: (wobbleCents + wobble).clamped(to: Self.wobbleCentsRange),
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
        case .cheerful: PlantSpeechStyle(language: "en-US", rate: 0.50, pitchCents: 500, effectRate: 1.00)
        case .dramatic: PlantSpeechStyle(language: "en-US", rate: 0.46, pitchCents: 300, effectRate: 0.95)
        case .grumpyGrandma: PlantSpeechStyle(language: "en-IE", rate: 0.42, pitchCents: 150, effectRate: 0.95)
        case .chillSurfer: PlantSpeechStyle(language: "en-AU", rate: 0.46, pitchCents: 200, effectRate: 0.90)
        case .politeButler: PlantSpeechStyle(language: "en-GB", rate: 0.48, pitchCents: 100, effectRate: 1.00)
        }
    }
}
