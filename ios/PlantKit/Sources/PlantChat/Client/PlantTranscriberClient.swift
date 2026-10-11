import Foundation

@MainActor
public protocol PlantTranscriberClient {
    var authorization: PlantSpeechAuthorization { get }
    func requestAuthorization(completion: @escaping (PlantSpeechAuthorization) -> Void)
    /// Installs the speech model if needed, ahead of the first tap.
    func prepare()
    func start(update: @escaping (PlantTranscriberEvent) -> Void)
    /// Stops the microphone, finalizes what was heard, then sends `.finished`.
    func finish()
    /// Stops at once. Nothing more is delivered.
    func cancel()
}

public enum PlantTranscriberEvent: Equatable, Sendable {
    /// Replaces the previous volatile text.
    case volatile(String)
    /// A finished segment, appended to the earlier ones.
    case final(String)
    case finished
    case failed(PlantTranscriberError)
}

public enum PlantTranscriberError: Error, Equatable, Sendable {
    /// The model assets are still installing.
    case preparing
    case transcription
}
