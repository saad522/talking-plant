import Foundation

@MainActor
public final class LanguageModelPlantVoiceLineLoader: PlantVoiceLineLoader {
    private let client: PlantLanguageModelClient
    private let personality: () -> PlantPersonality
    private let plantName: String

    public enum Error: Swift.Error, Equatable {
        case unavailable
        /// The model's line was empty, too long, or had a number in it.
        case invalidLine
        case generation
    }

    /// - Parameter personality: Read on every load, so a changed personality applies to the next line.
    public init(client: PlantLanguageModelClient, personality: @escaping () -> PlantPersonality, plantName: String) {
        self.client = client
        self.personality = personality
        self.plantName = plantName
    }

    public func load(_ request: PlantVoiceLineRequest, completion: @escaping (PlantVoiceLineLoader.Result) -> Void) {
        guard client.isAvailable else {
            completion(.failure(Error.unavailable))
            return
        }

        let session = client.makeSession(
            instructions: PlantVoicePrompt.instructions(personality: personality(), plantName: plantName),
            canReadHistory: false
        )
        session.respond(to: PlantVoicePrompt.line(request.facts, purpose: request.purpose)) { result in
            switch result {
            case .success(let text):
                completion(PlantVoicePrompt.cleanLine(text).map { .success($0) } ?? .failure(Error.invalidLine))
            case .failure:
                completion(.failure(Error.generation))
            }
        }
    }
}
