import PlantShared

/// Decides whether Sprout says its line on its own (docs/plans/P1-alive.md D7).
public enum PlantMonitorSpeechPolicy {
    /// Not while offline. Otherwise when the mood differs from the last one spoken, or it is a new day.
    public static func shouldSpeak(mood: PlantMood, lastMood: PlantMood?, lastDay: String?, today: String) -> Bool {
        guard mood != .offline else { return false }
        return mood != lastMood || today != lastDay
    }
}
