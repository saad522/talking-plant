import PlantShared

/// What the plant knows about itself right now. The model only puts it into words.
public struct PlantVoiceFacts: Equatable, Sendable {
    public let mood: PlantMood
    public let isSleeping: Bool
    public let reading: PlantReading?

    public init(mood: PlantMood, isSleeping: Bool, reading: PlantReading?) {
        self.mood = mood
        self.isSleeping = isSleeping
        self.reading = reading
    }
}
