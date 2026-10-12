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
    private let transcriptLoader: PlantTranscriptLoader
    private let audioSession: PlantAudioSessionClient
    private let synthesizer: PlantSynthesizerClient
    private let spokenReplies: PlantSpokenReplySettings
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
    private var activity: PlantChatActivity = .idle
    private var isAudioSessionActive: Bool = false
    /// Changes whenever listening ends, so late transcripts of an earlier turn are dropped.
    private var listening: Int = 0
    /// Changes whenever speech starts or is cut off, so the end of an earlier utterance is dropped.
    private var speech: Int = 0
    /// Whether the reply being waited for will be spoken.
    private var speaksPendingReply: Bool = false

    public let personalities: [PlantPersonalityViewModel] = PlantPersonality.allCases.map(PlantPersonalityViewModel.init)

    public let backLabel: String = String.localised(key: "plant.chat.back.label")
    public let personalityLabel: String = String.localised(key: "plant.chat.personality.label")
    public let placeholderLabel: String = String.localised(key: "plant.chat.input.placeholder")
    public let sendLabel: String = String.localised(key: "plant.chat.send.label")
    public let listeningLabel: String = String.localised(key: "plant.chat.listening.label")
    public let stopListeningLabel: String = String.localised(key: "plant.chat.mic.stop.label")
    public let keyboardLabel: String = String.localised(key: "plant.chat.keyboard.label")
    public let endLabel: String = String.localised(key: "plant.chat.end.label")
    public let speakRepliesLabel: String = String.localised(key: "plant.chat.speakReplies.label")
    public var talkLabel: String {
        String(format: String.localised(key: "plant.chat.mic.talk.label"), plantName)
    }
    public var interruptLabel: String {
        String(format: String.localised(key: "plant.chat.mic.interrupt.label"), plantName)
    }
    public var unavailableLabel: String {
        String(format: String.localised(key: "plant.chat.unavailable.notice"), plantName)
    }

    public var loadedMessages: Observer<[PlantChatMessageViewModel]>?
    public var loadedTyping: Observer<Bool>?
    public var loadedMood: Observer<PlantChatMoodViewModel>?
    public var loadedAvailability: Observer<Bool>?
    public var loadedPersonality: Observer<PlantPersonality>?
    public var loadedActivity: Observer<PlantChatActivity>?
    /// The live text; empty when not listening.
    public var loadedTranscript: Observer<String>?
    public var loadedInputMode: Observer<PlantChatInputMode>?
    public var loadedMicrophoneNotice: Observer<PlantChatMicrophoneNoticeViewModel?>?
    public var loadedSpokenReplies: Observer<Bool>?

    public init(
        chatLoader: PlantChatLoader,
        lineLoader: PlantVoiceLineLoader,
        factsLoader: PlantVoiceFactsLoader,
        settings: PlantPersonalitySettings,
        transcriptLoader: PlantTranscriptLoader,
        audioSession: PlantAudioSessionClient,
        synthesizer: PlantSynthesizerClient,
        spokenReplies: PlantSpokenReplySettings,
        plantName: String,
        currentDate: @escaping () -> Date = Date.init,
        actionHandler: @escaping (PlantChatAction) -> Void
    ) {
        self.chatLoader = chatLoader
        self.lineLoader = lineLoader
        self.factsLoader = factsLoader
        self.settings = settings
        self.transcriptLoader = transcriptLoader
        self.audioSession = audioSession
        self.synthesizer = synthesizer
        self.spokenReplies = spokenReplies
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
        loadedSpokenReplies?(spokenReplies.isEnabled)
        factsLoader.subscribe { [weak self] in
            self?.loadFacts()
        }
        loadedAvailability?(chatLoader.isAvailable)
        prepareVoice()
        greet()
    }

    public func send(_ text: String) {
        guard activity != .listening else { return }
        submit(text, speaksReply: false)
    }

    /// The one path for typed and spoken turns.
    @discardableResult
    private func submit(_ text: String, speaksReply: Bool) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false, isReplying == false else { return false }

        append(text, from: .user)
        speaksPendingReply = speaksReply
        isReplying = true
        loadedTyping?(true)
        setActivity(.thinking)

        let conversation = conversation
        let reply = { [weak self] (text: String) in
            guard let self, self.conversation == conversation else { return }
            self.isReplying = false
            self.append(text, from: .plant)
            self.loadedTyping?(false)
            let spoken = self.speaksPendingReply ? PlantSpeechText.clean(text) : ""
            self.speaksPendingReply = false
            if spoken.isEmpty {
                self.deactivateAudioSession()
                self.setActivity(.idle)
            } else {
                self.speak(spoken)
            }
        }
        guard let facts = latestFacts else {
            reply(PlantChatTemplate.reply(facts: nil))
            return true
        }
        chatLoader.send(text, facts: facts) { result in
            switch result {
            case .success(let text):
                reply(text)
            case .failure:
                reply(PlantChatTemplate.reply(facts: facts))
            }
        }
        return true
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

    public func micTap() {
        switch activity {
        case .idle:
            switch transcriptLoader.authorization {
            case .notDetermined:
                transcriptLoader.requestAuthorization { [weak self] authorization in
                    guard let self, self.activity == .idle else { return }
                    if authorization == .authorized {
                        self.startListening()
                    } else {
                        self.showNotice(for: authorization)
                    }
                }
            case .authorized:
                startListening()
            case let authorization:
                showNotice(for: authorization)
            }
        case .listening:
            transcriptLoader.stop()
        case .speaking:
            cancelSpeech()
            startListening()
        case .thinking:
            break
        }
    }

    public func setSpokenReplies(_ isEnabled: Bool) {
        spokenReplies.save(isEnabled: isEnabled)
        loadedSpokenReplies?(isEnabled)
        guard isEnabled == false else { return }
        speaksPendingReply = false
        if activity == .speaking {
            stopVoice()
        }
    }

    public func keyboardTap() {
        stopVoice()
        loadedInputMode?(.keyboard)
    }

    public func voiceTap() {
        let authorization = transcriptLoader.authorization
        guard isBlocked(authorization) == false else {
            showNotice(for: authorization)
            return
        }
        loadedMicrophoneNotice?(nil)
        loadedInputMode?(.voice)
    }

    public func endTap() {
        stopVoice()
        actionHandler(.backTap)
    }

    /// Called when the screen goes away or the scene leaves `.active`.
    public func disappear() {
        stopVoice()
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

    private func prepareVoice() {
        let authorization = transcriptLoader.authorization
        if isBlocked(authorization) {
            showNotice(for: authorization)
        }
        transcriptLoader.prepare()
        audioSession.subscribe { [weak self] event in
            self?.handle(event)
        }
    }

    private func isBlocked(_ authorization: PlantSpeechAuthorization) -> Bool {
        switch authorization {
        case .denied, .restricted, .unsupported: true
        case .notDetermined, .authorized: false
        }
    }

    private func showNotice(for authorization: PlantSpeechAuthorization) {
        guard let notice = PlantChatMicrophoneNoticeViewModel(authorization: authorization, actionHandler: actionHandler) else { return }
        loadedMicrophoneNotice?(notice)
        loadedInputMode?(.keyboard)
    }

    private func showFailureNotice(_ failure: PlantChatMicrophoneNoticeViewModel.Failure) {
        loadedMicrophoneNotice?(PlantChatMicrophoneNoticeViewModel(failure: failure, actionHandler: actionHandler))
    }

    private func startListening() {
        // Cutting speech off keeps the session, so music doesn't resume between the two.
        if isAudioSessionActive == false {
            guard audioSession.activate() else {
                showFailureNotice(.audio)
                return
            }
            isAudioSessionActive = true
        }
        loadedMicrophoneNotice?(nil)
        setActivity(.listening)
        listening += 1
        let listening = listening
        transcriptLoader.start { [weak self] result in
            guard let self, self.listening == listening else { return }
            self.handle(result)
        }
    }

    private func handle(_ result: PlantTranscriptLoader.Result) {
        switch result {
        case .success(let transcript) where transcript.isFinal == false:
            loadedTranscript?(transcript.text)
        case .success(let transcript):
            finishListening()
            if submit(transcript.text, speaksReply: spokenReplies.isEnabled) == false {
                deactivateAudioSession()
                setActivity(.idle)
            }
        case .failure(let error):
            finishListening()
            deactivateAudioSession()
            setActivity(.idle)
            showFailureNotice(error as? TranscriberPlantTranscriptLoader.Error == .preparing ? .preparing : .transcription)
        }
    }

    private func handle(_ event: PlantAudioSessionEvent) {
        switch (event, activity) {
        case (.interruptionBegan, .listening), (.outputDeviceLost, .listening),
             (.interruptionBegan, .speaking), (.outputDeviceLost, .speaking):
            stopVoice()
        case (.interruptionBegan, .thinking):
            speaksPendingReply = false
            deactivateAudioSession()
        default:
            break
        }
    }

    /// Ends the turn without sending anything. A reply still on its way is shown, not spoken.
    private func stopVoice() {
        speaksPendingReply = false
        if activity == .listening {
            finishListening()
            transcriptLoader.cancel()
            setActivity(.idle)
        }
        if activity == .speaking {
            cancelSpeech()
            setActivity(.idle)
        }
        deactivateAudioSession()
    }

    private func speak(_ text: String) {
        speech += 1
        let speech = speech
        setActivity(.speaking)
        synthesizer.speak(text, style: settings.load().speechStyle) { [weak self] in
            guard let self, self.speech == speech else { return }
            self.deactivateAudioSession()
            self.setActivity(.idle)
        }
    }

    private func cancelSpeech() {
        speech += 1
        synthesizer.stop()
    }

    private func finishListening() {
        listening += 1
        loadedTranscript?("")
    }

    private func deactivateAudioSession() {
        guard isAudioSessionActive else { return }
        isAudioSessionActive = false
        audioSession.deactivate()
    }

    private func setActivity(_ activity: PlantChatActivity) {
        guard self.activity != activity else { return }
        self.activity = activity
        loadedActivity?(activity)
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
        stopVoice()
        if activity == .thinking {
            setActivity(.idle)
        }
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
