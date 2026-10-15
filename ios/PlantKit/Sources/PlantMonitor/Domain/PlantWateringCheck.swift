import Foundation

/// Decides from two moisture values whether the plant was watered.
public enum PlantWateringCheck {
    /// Points of moisture a reading has to gain over the baseline.
    public static let minimumRise: Double = 10
    /// How long after a Water tap a rise still counts.
    public static let window: TimeInterval = 600

    public static func isWatered(baseline: Double, current: Double) -> Bool {
        current - baseline >= minimumRise
    }
}
