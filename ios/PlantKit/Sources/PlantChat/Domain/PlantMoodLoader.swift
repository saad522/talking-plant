import PlantShared

/// The plant's mood, as PlantChat needs it. The app adapts the monitor's health loader to this.
@MainActor
public protocol PlantMoodLoader {
    typealias Result = Swift.Result<PlantMoodState, Error>

    func load(completion: @escaping (Result) -> Void)
    /// Called whenever the mood should be evaluated again.
    func subscribe(update: @escaping () -> Void)
}
