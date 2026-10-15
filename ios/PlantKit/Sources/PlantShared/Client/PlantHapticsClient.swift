import Foundation

public enum PlantHaptic: Equatable, Sendable {
    /// Light impact: a button press.
    case tap
    /// Success notification: something worked (watered, calibration saved).
    case success
    /// Soft impact: Sprout bouncing or reacting.
    case bump
    /// Selection changed: a toggle, a segmented control or a picker.
    case selection
}

/// Plays haptic feedback. Implementations respect the system's haptics setting.
@MainActor
public protocol PlantHapticsClient {
    func play(_ haptic: PlantHaptic)
}
