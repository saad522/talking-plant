import Foundation

@MainActor
public protocol PlantVoiceFactsLoader {
    typealias Result = Swift.Result<PlantVoiceFacts, Error>

    func load(completion: @escaping (Result) -> Void)
    /// Called whenever the facts should be loaded again.
    func subscribe(update: @escaping () -> Void)
}
