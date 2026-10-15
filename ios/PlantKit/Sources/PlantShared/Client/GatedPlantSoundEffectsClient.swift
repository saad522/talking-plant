import Foundation

/// Plays nothing while sound effects are off or Sprout's voice is speaking.
@MainActor
public final class GatedPlantSoundEffectsClient: PlantSoundEffectsClient {
    private let decoratee: PlantSoundEffectsClient
    private let isEnabled: () -> Bool
    private let isVoiceSpeaking: () -> Bool

    public init(
        decoratee: PlantSoundEffectsClient,
        isEnabled: @escaping () -> Bool,
        isVoiceSpeaking: @escaping () -> Bool
    ) {
        self.decoratee = decoratee
        self.isEnabled = isEnabled
        self.isVoiceSpeaking = isVoiceSpeaking
    }

    public func play(_ effect: PlantSoundEffect) {
        guard isEnabled(), isVoiceSpeaking() == false else { return }
        decoratee.play(effect)
    }
}
