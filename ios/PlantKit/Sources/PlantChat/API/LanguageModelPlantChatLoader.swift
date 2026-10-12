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
    private var turnsInSession = 0
    private static let repeatWindow = 3
    private static let maximumTurnsPerSession = 6
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
        if turnsInSession >= Self.maximumTurnsPerSession {
            resetSession()
        }
        respond(to: prompt, facts: facts, retries: .init(), completion: completion)
    }

    public func reset() {
        resetSession()
        recentReplies = []
    }

    private func resetSession() {
        session = nil
        sessionPersonality = nil
        turnsInSession = 0
    }

    /// Each problem gets one fresh session, then the template.
    private struct Retries {
        var context = true
        var repeated = true
        var rejected = true
    }

    private func respond(
        to prompt: String,
        facts: PlantVoiceFacts,
        retries: Retries,
        completion: @escaping (PlantChatLoader.Result) -> Void
    ) {
        let session = currentSession()
        turnsInSession += 1
        session.respond(to: prompt) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let text):
                #if DEBUG
                Self.logger.debug("Reply:\n\(text, privacy: .public)")
                #endif
                let reply = PlantChatReplyGuard.clean(text)
                var retries = retries
                if PlantChatReplyGuard.isRejected(reply) {
                    guard retries.rejected else { return deliverTemplate(facts, completion) }
                    retries.rejected = false
                    resetSession()
                    respond(to: prompt, facts: facts, retries: retries, completion: completion)
                } else if recentReplies.contains(Self.normalized(reply)) {
                    guard retries.repeated else { return deliverTemplate(facts, completion) }
                    retries.repeated = false
                    resetSession()
                    respond(to: prompt, facts: facts, retries: retries, completion: completion)
                } else {
                    remember(reply)
                    completion(.success(reply))
                }
            case .failure(let error):
                if retries.context, error as? PlantLanguageModelError == .contextTooLong {
                    var retries = retries
                    retries.context = false
                    resetSession()
                    respond(to: prompt, facts: facts, retries: retries, completion: completion)
                } else {
                    completion(.failure(Error.generation))
                }
            }
        }
    }

    private func deliverTemplate(_ facts: PlantVoiceFacts, _ completion: (PlantChatLoader.Result) -> Void) {
        let template = PlantChatTemplate.reply(facts: facts)
        remember(template)
        completion(.success(template))
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
