import Foundation

/// Produces one short line in the plant's voice.
@MainActor
public protocol PlantVoiceLineLoader {
    typealias Result = Swift.Result<String, Error>

    func load(_ request: PlantVoiceLineRequest, completion: @escaping (Result) -> Void)
}
