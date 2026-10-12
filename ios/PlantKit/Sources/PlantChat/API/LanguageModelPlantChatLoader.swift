import Foundation
import os

@MainActor
public final class LanguageModelPlantChatLoader: PlantChatLoader {
    private let client: PlantLanguageModelClient
    private let personality: () -> PlantPersonality
    private let plantName: String
    private var session: PlantLanguageModelSession?
    private var sessionPersonality: PlantPersonality?
    private var recentReplies: [String] = []
    private static let repeatWindow = 3
    #if DEBUG
    private static let logger = Logger(subsystem: "TalkingPlant", category: "chat")
    #endif

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
        let prompt = PlantVoicePrompt.message(text, facts: facts)
        #if DEBUG
        Self.logger.debug("Prompt:\n\(prompt, privacy: .public)")
        #endif
        respond(to: prompt, facts: facts, canRetryContext: true, canRetryRepeat: true, completion: completion)
    }

    public func reset() {
        resetSession()
        recentReplies = []
    }

    private func resetSession() {
        session = nil
        sessionPersonality = nil
    }

    private func respond(
        to prompt: String,
        facts: PlantVoiceFacts,
        canRetryContext: Bool,
        canRetryRepeat: Bool,
        completion: @escaping (PlantChatLoader.Result) -> Void
    ) {
        currentSession().respond(to: prompt) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let text):
                #if DEBUG
                Self.logger.debug("Reply:\n\(text, privacy: .public)")
                #endif
                if recentReplies.contains(Self.normalized(text)) {
                    if canRetryRepeat {
                        resetSession()
                        respond(to: prompt, facts: facts, canRetryContext: canRetryContext, canRetryRepeat: false, completion: completion)
                    } else {
                        let template = PlantChatTemplate.reply(facts: facts)
                        remember(template)
                        completion(.success(template))
                    }
                } else {
                    remember(text)
                    completion(.success(text))
                }
            case .failure(let error):
                if canRetryContext, error as? PlantLanguageModelError == .contextTooLong {
                    resetSession()
                    respond(to: prompt, facts: facts, canRetryContext: false, canRetryRepeat: canRetryRepeat, completion: completion)
                } else {
                    completion(.failure(Error.generation))
                }
            }
        }
    }

    private func remember(_ reply: String) {
        recentReplies = Array((recentReplies + [Self.normalized(reply)]).suffix(Self.repeatWindow))
    }

    /// Lowercased, trimmed and without punctuation, so "I'm fine!" and "im fine" count as the same reply.
    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: .punctuationCharacters).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
