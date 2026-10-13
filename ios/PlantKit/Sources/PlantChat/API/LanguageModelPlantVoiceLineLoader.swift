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
                guard let line = PlantVoicePrompt.cleanLine(text) else { return completion(.failure(Error.invalidLine)) }
                completion(.success(Self.fitting(line, request)))
            case .failure:
                completion(.failure(Error.generation))
            }
        }
    }

    /// A greeting that doesn't fit the mood is replaced by the mood's template.
    private static func fitting(_ line: String, _ request: PlantVoiceLineRequest) -> String {
        let facts = request.facts
        guard request.purpose == .greeting, PlantChatReplyGuard.greetingFits(line, mood: facts.mood) == false else { return line }
        return PlantChatTemplate.speech(mood: facts.mood, isSleeping: facts.isSleeping)
    }
}
