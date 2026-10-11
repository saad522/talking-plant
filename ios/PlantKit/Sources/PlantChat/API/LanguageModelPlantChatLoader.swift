import Foundation

@MainActor
public final class LanguageModelPlantChatLoader: PlantChatLoader {
    private let client: PlantLanguageModelClient
    private let personality: () -> PlantPersonality
    private let plantName: String
    private var session: PlantLanguageModelSession?
    private var sessionPersonality: PlantPersonality?

    public enum Error: Swift.Error, Equatable {
        case unavailable
        case generation
    }

    /// - Parameter personality: Read on every send. A different personality starts a new session.
    public init(client: PlantLanguageModelClient, personality: @escaping () -> PlantPersonality, plantName: String) {
        self.client = client
        self.personality = personality
        self.plantName = plantName
    }

    public var isAvailable: Bool {
        client.isAvailable
    }

    public func send(_ text: String, facts: PlantVoiceFacts, completion: @escaping (PlantChatLoader.Result) -> Void) {
        guard client.isAvailable else {
            completion(.failure(Error.unavailable))
            return
        }
        respond(to: PlantVoicePrompt.message(text, facts: facts), canRetry: true, completion: completion)
    }

    public func reset() {
        session = nil
        sessionPersonality = nil
    }

    private func respond(to prompt: String, canRetry: Bool, completion: @escaping (PlantChatLoader.Result) -> Void) {
        currentSession().respond(to: prompt) { [weak self] result in
            switch result {
            case .success(let text):
                completion(.success(text))
            case .failure(let error):
                if canRetry, error as? PlantLanguageModelError == .contextTooLong, let self {
                    self.reset()
                    self.respond(to: prompt, canRetry: false, completion: completion)
                } else {
                    completion(.failure(Error.generation))
                }
            }
        }
    }

    private func currentSession() -> PlantLanguageModelSession {
        let personality = personality()
        if let session, sessionPersonality == personality {
            return session
        }
        let session = client.makeSession(
            instructions: PlantVoicePrompt.instructions(personality: personality, plantName: plantName),
            canReadHistory: true
        )
        self.session = session
        self.sessionPersonality = personality
        return session
    }
}
