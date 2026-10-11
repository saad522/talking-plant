import Foundation
import PlantShared

@MainActor
public final class PlantChatViewModel {
    public typealias Observer<T> = (T) -> Void

    private let chatLoader: PlantChatLoader
    private let lineLoader: PlantVoiceLineLoader
    private let factsLoader: PlantVoiceFactsLoader
    private let settings: PlantPersonalitySettings
    private let plantName: String
    private let actionHandler: (PlantChatAction) -> Void
    private var appeared: Bool = false
    private var latestFacts: PlantVoiceFacts?
    private var messages: [PlantChatMessageViewModel] = []
    private var nextMessageID: Int = 0
    private var isReplying: Bool = false
    /// Changes when the conversation restarts, so answers to the old one are dropped.
    private var conversation: Int = 0

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
        actionHandler: @escaping (PlantChatAction) -> Void
    ) {
        self.chatLoader = chatLoader
        self.lineLoader = lineLoader
        self.factsLoader = factsLoader
        self.settings = settings
        self.plantName = plantName
        self.actionHandler = actionHandler
    }

    public func appear() {
        guard appeared == false else { return }
        appeared = true
        loadedPersonality?(settings.load())
        factsLoader.subscribe { [weak self] in
            self?.loadFacts()
        }
        loadedAvailability?(chatLoader.isAvailable)
        loadFacts { [weak self] in
            self?.greet()
        }
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
        chatLoader.reset()
        conversation += 1
        messages = []
        if isReplying {
            isReplying = false
            loadedTyping?(false)
        }
        loadedPersonality?(personality)
        loadedMessages?(messages)
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

    private func greet() {
        let conversation = conversation
        guard let facts = latestFacts else {
            append(PlantChatTemplate.greeting, from: .plant)
            return
        }
        lineLoader.load(PlantVoiceLineRequest(facts: facts, purpose: .greeting)) { [weak self] result in
            guard let self, self.conversation == conversation else { return }
            switch result {
            case .success(let line):
                self.append(line, from: .plant)
            case .failure:
                self.append(PlantChatTemplate.greeting, from: .plant)
            }
        }
    }

    private func append(_ text: String, from sender: PlantChatMessageViewModel.Sender) {
        messages.append(PlantChatMessageViewModel(id: nextMessageID, text: text, sender: sender))
        nextMessageID += 1
        loadedMessages?(messages)
    }
}
