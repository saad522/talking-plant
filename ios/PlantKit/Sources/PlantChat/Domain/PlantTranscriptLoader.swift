import Foundation

@MainActor
public protocol PlantTranscriptLoader {
    typealias Result = Swift.Result<PlantTranscript, Error>

    var authorization: PlantSpeechAuthorization { get }
    func requestAuthorization(completion: @escaping (PlantSpeechAuthorization) -> Void)
    func prepare()
    /// Partial transcripts, then exactly one final transcript (empty when nothing was heard).
    func start(update: @escaping (Result) -> Void)
    /// Stops listening. The final transcript follows.
    func stop()
    /// Stops listening. Nothing more is delivered.
    func cancel()
}
