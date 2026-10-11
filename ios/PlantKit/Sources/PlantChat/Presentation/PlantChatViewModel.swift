import Foundation
import PlantShared

@MainActor
public final class PlantChatViewModel {
    /// Reopening Chat after this long without a message starts a new conversation.
    static let conversationTimeout: TimeInterval = 30 * 60

    public typealias Observer<T> = (T) -> Void

    private let chatLoader: PlantChatLoader
    private let lineLoader: PlantVoiceLineLoader
    private let factsLoader: PlantVoiceFactsLoader
    private let settings: PlantPersonalitySettings
    private let plantName: String
    private let currentDate: () -> Date
    private let actionHandler: (PlantChatAction) -> Void
    private var appeared: Bool = false
    private var latestFacts: PlantVoiceFacts?
    private var messages: [PlantChatMessageViewModel] = []
    private var nextMessageID: Int = 0
    private var isReplying: Bool = false
    /// Changes when the conversation restarts, so answers to the old one are dropped.
    private var conversation: Int = 0
    private var lastMessageDate: Date?
    private var lastMessageMood: PlantMood?

    public let personalities: [PlantPersonalityViewModel] = PlantPersonality.allCases.map(PlantPersonalityViewModel.init)

    public let backLabel: String = String.localised(key: "plant.chat.back.label")
    public let personalityLabel: String = String.localised(key: "plant.chat.personality.label")
    public let placeholderLabel: String = String.localised(key: "plant.chat.input.placeholder")
    public let sendLabel: String = String.localised(key: "plant.chat.send.label")
    public var unavailableLabel: String {
        String(format: String.localised(key: "plant.chat.unavailable.notice"), plantName)
    }

    public var loadedMessages: Observer<[PlantChatMessageViewModel]>?
    public var loadedTyping: Observer<Bool>?
    public var loadedMood: Observer<PlantChatMoodViewModel>?
    public var loadedAvailability: Observer<Bool>?
    public var loadedPersonality: Observer<PlantPersonality>?

    public init(
        chatLoader: PlantChatLoader,
        lineLoader: PlantVoiceLineLoader,
        factsLoader: PlantVoiceFactsLoader,
        settings: PlantPersonalitySettings,
        plantName: String,
        currentDate: @escaping () -> Date = Date.init,
        actionHandler: @escaping (PlantChatAction) -> Void
    ) {
        self.chatLoader = chatLoader
        self.lineLoader = lineLoader
        self.factsLoader = factsLoader
        self.settings = settings
        self.plantName = plantName
        self.currentDate = currentDate
        self.actionHandler = actionHandler
    }

    /// - Note: Reopening keeps the conversation, unless the mood changed or 30 minutes passed since the last message.
    public func appear() {
        guard appeared == false else {
            loadFacts { [weak self] in
                self?.restartIfOutdated()
            }
            return
        }
        appeared = true
        loadedPersonality?(settings.load())
        factsLoader.subscribe { [weak self] in
            self?.loadFacts()
        }
        loadedAvailability?(chatLoader.isAvailable)
        greet()
    }

    public func send(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false, isReplying == false else { return }

        append(text, from: .user)
        isReplying = true
        loadedTyping?(true)

        let conversation = conversation
        let reply = { [weak self] (text: String) in
            guard let self, self.conversation == conversation else { return }
            self.isReplying = false
            self.append(text, from: .plant)
            self.loadedTyping?(false)
        }
        guard let facts = latestFacts else {
            reply(PlantChatTemplate.reply(facts: nil))
            return
        }
        chatLoader.send(text, facts: facts) { result in
            switch result {
            case .success(let text):
                reply(text)
            case .failure:
                reply(PlantChatTemplate.reply(facts: facts))
            }
        }
    }

    public func select(_ personality: PlantPersonality) {
        settings.save(personality)
        restartConversation()
        loadedPersonality?(personality)
        greet()
    }

    public func backTap() {
        actionHandler(.backTap)
    }

    // MARK: - Private helpers

    /// A failed load keeps the last facts.
    private func loadFacts(then completion: (() -> Void)? = nil) {
        factsLoader.load { [weak self] result in
            if case .success(let facts) = result {
                self?.latestFacts = facts
                self?.loadedMood?(PlantChatMoodViewModel(mood: facts.mood))
            }
            completion?()
        }
    }

    private func restartIfOutdated() {
        guard let lastMessageDate else { return }
        let moodChanged = lastMessageMood != nil && latestFacts != nil && lastMessageMood != latestFacts?.mood
        let timedOut = currentDate().timeIntervalSince(lastMessageDate) > Self.conversationTimeout
        guard moodChanged || timedOut else { return }
        restartConversation()
        greet()
    }

    /// Drops the messages and any reply still on its way.
    private func restartConversation() {
        chatLoader.reset()
        conversation += 1
        messages = []
        lastMessageDate = nil
        lastMessageMood = nil
        if isReplying {
            isReplying = false
            loadedTyping?(false)
        }
        loadedMessages?(messages)
    }

    /// Loads fresh facts first, so the greeting never describes an old mood.
    private func greet() {
        let conversation = conversation
        loadFacts { [weak self] in
            guard let self, self.conversation == conversation else { return }
            guard let facts = self.latestFacts else {
                self.append(PlantChatTemplate.greeting, from: .plant)
                return
            }
            self.lineLoader.load(PlantVoiceLineRequest(facts: facts, purpose: .greeting)) { [weak self] result in
                guard let self, self.conversation == conversation else { return }
                switch result {
                case .success(let line) where self.latestFacts?.mood == facts.mood:
                    self.append(line, from: .plant)
                default:
                    self.append(PlantChatTemplate.greeting, from: .plant)
                }
            }
        }
    }

    private func append(_ text: String, from sender: PlantChatMessageViewModel.Sender) {
        messages.append(PlantChatMessageViewModel(id: nextMessageID, text: text, sender: sender))
        lastMessageDate = currentDate()
        lastMessageMood = latestFacts?.mood
        nextMessageID += 1
        loadedMessages?(messages)
    }
}
