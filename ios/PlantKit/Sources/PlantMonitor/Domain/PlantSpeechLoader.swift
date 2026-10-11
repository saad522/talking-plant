import PlantShared

/// Produces the line in the home speech bubble. The app adapts PlantChat's line loader to this.
@MainActor
public protocol PlantSpeechLoader {
    typealias Result = Swift.Result<String, Error>

    func load(mood: PlantMood, isSleeping: Bool, reading: PlantReading?, completion: @escaping (Result) -> Void)
}
