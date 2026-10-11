import PlantShared

/// The plant's mood plus every current issue behind it.
public struct PlantMoodState: Equatable, Sendable {
    public let mood: PlantMood
    /// Every current issue, most important first. Empty when nothing is wrong.
    public let problems: [PlantMood]

    public init(mood: PlantMood, problems: [PlantMood]) {
        self.mood = mood
        self.problems = problems
    }
}
