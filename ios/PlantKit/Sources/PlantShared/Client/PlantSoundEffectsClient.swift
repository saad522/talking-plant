import Foundation

public enum PlantSoundEffect: Equatable, Sendable {
    /// Something worked: watered, calibration saved.
    case chime
    /// Sprout reacting to a shake.
    case pop
    /// The cold-launch greeting rising.
    case greet

    /// The sound file's name, without extension.
    public var fileName: String {
        switch self {
        case .chime: "sprout_chime"
        case .pop: "sprout_pop"
        case .greet: "sprout_greet"
        }
    }
}

/// Plays Sprout's short reward sounds. Implementations never throw: a sound that can't play is skipped.
@MainActor
public protocol PlantSoundEffectsClient {
    func play(_ effect: PlantSoundEffect)
}
