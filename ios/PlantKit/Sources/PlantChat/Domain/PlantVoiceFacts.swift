import PlantShared

/// What the plant knows about itself right now. The model only puts it into words.
public struct PlantVoiceFacts: Equatable, Sendable {
    public let mood: PlantMood
    public let isSleeping: Bool
    public let reading: PlantReading?
    /// Every current issue, so a sensor without one can be called fine. Empty means only `mood` is known.
    public let problems: [PlantMood]
    /// Set when the soil was watered within the last hour.
    public let wateredMinutesAgo: Int?
    /// From the phone's clock, so greetings fit the time. Nil when unknown.
    public let timeOfDay: PlantTimeOfDay?

    public init(
        mood: PlantMood,
        isSleeping: Bool,
        reading: PlantReading?,
        problems: [PlantMood] = [],
        wateredMinutesAgo: Int? = nil,
        timeOfDay: PlantTimeOfDay? = nil
    ) {
        self.mood = mood
        self.isSleeping = isSleeping
        self.reading = reading
        self.problems = problems
        self.wateredMinutesAgo = wateredMinutesAgo
        self.timeOfDay = timeOfDay
    }
}
