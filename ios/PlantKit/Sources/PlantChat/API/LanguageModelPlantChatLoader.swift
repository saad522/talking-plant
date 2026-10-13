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
        respond(to: prompt, facts: facts, intent: PlantChatIntent(text), retried: [], completion: completion)
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

    /// Each problem gets one fresh session, then the template. A context that is too long a second time fails.
    private enum Problem {
        case contextTooLong
        case rejected
        case confusedRoles
        case contradictedMood
        case repeated
    }

    /// For a status question only the model's first sentence (the feeling) is kept, followed by the exact values.
    private func respond(
        to prompt: String,
        facts: PlantVoiceFacts,
        intent: PlantChatIntent,
        retried: Set<Problem>,
        completion: @escaping (PlantChatLoader.Result) -> Void
    ) {
        let session = currentSession()
        turnsInSession += 1
        session.respond(to: prompt) { [weak self] result in
            guard let self else { return }
            let retry = { (problem: Problem) in
                self.resetSession()
                self.respond(to: prompt, facts: facts, intent: intent, retried: retried.union([problem]), completion: completion)
            }
            switch result {
            case .success(let text):
                #if DEBUG
                Self.logger.debug("Reply:\n\(text, privacy: .public)")
                #endif
                let cleaned = PlantChatReplyGuard.clean(text)
                let reply = intent == .status ? PlantChatReplyGuard.firstSentence(of: cleaned) : cleaned
                if let problem = problem(with: reply, facts: facts) {
                    guard retried.contains(problem) == false else { return deliverTemplate(facts, completion) }
                    retry(problem)
                } else {
                    remember(reply)
                    completion(.success(intent == .status ? reply + " " + PlantChatTemplate.status(of: facts.reading) : reply))
                }
            case .failure(let error):
                if retried.contains(.contextTooLong) == false, error as? PlantLanguageModelError == .contextTooLong {
                    retry(.contextTooLong)
                } else {
                    completion(.failure(Error.generation))
                }
            }
        }
    }

    private func problem(with reply: String, facts: PlantVoiceFacts) -> Problem? {
        if PlantChatReplyGuard.isRejected(reply) { return .rejected }
        if PlantChatReplyGuard.confusesRoles(reply) { return .confusedRoles }
        if PlantChatReplyGuard.contradicts(reply, mood: facts.mood) { return .contradictedMood }
        if PlantChatReplyGuard.repeats(reply, anyOf: recentReplies) { return .repeated }
        return nil
    }

    private func deliverTemplate(_ facts: PlantVoiceFacts, _ completion: (PlantChatLoader.Result) -> Void) {
        let template = PlantChatTemplate.reply(facts: facts)
        remember(template)
        completion(.success(template))
    }

    private func remember(_ reply: String) {
        recentReplies = Array((recentReplies + [reply]).suffix(Self.repeatWindow))
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
