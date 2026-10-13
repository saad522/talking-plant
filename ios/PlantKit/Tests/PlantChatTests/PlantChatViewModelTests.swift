import PlantShared
import XCTest
@testable import PlantChat

@MainActor
final class PlantChatViewModelTests: PlantChatXCTestCase {
    func test_init_doesNotMessageCollaborators() {
        let sut = makeSUT()

        XCTAssertEqual(sut.factsLoader.messages, [])
        XCTAssertEqual(sut.lineLoader.requests, [])
        XCTAssertEqual(sut.chatLoader.sends, [])
        XCTAssertEqual(sut.chatLoader.resetCount, 0)
    }

    func test_init_listsAvailablePersonalitiesWithLabel() {
        let sut = makeSUT()

        XCTAssertEqual(sut.viewModel.personalities.map(\.personality), PlantPersonality.available)
        XCTAssertEqual(Set(sut.viewModel.personalities.map(\.label)).count, PlantPersonality.available.count)
        XCTAssertEqual(sut.viewModel.personalities.first?.label, "Cheerful")
    }

    func test_init_providesLabelsForTheScreen() {
        let sut = makeSUT()

        XCTAssertEqual(sut.viewModel.backLabel, "Back")
        XCTAssertEqual(sut.viewModel.personalityLabel, "Personality")
        XCTAssertEqual(sut.viewModel.placeholderLabel, "Say something…")
        XCTAssertEqual(sut.viewModel.sendLabel, "Send")
        XCTAssertTrue(sut.viewModel.unavailableLabel.contains("Apple Intelligence"))
    }

    // MARK: - appear

    func test_appear_subscribesOnceAndReloadsFactsWhenReopened() {
        let sut = makeSUT()

        sut.viewModel.appear()
        sut.viewModel.appear()

        XCTAssertEqual(sut.factsLoader.messages, [.subscribeFacts, .loadFacts, .loadFacts])
    }

    func test_appear_deliversSavedPersonality() {
        let sut = makeSUT(savedPersonality: .politeButler)
        var received: [PlantPersonality] = []
        sut.viewModel.loadedPersonality = { received.append($0) }

        sut.viewModel.appear()

        XCTAssertEqual(received, [.politeButler])
    }

    func test_appear_deliversAvailabilityOfChatLoader() {
        [true, false].forEach { available in
            let sut = makeSUT()
            sut.chatLoader.isAvailable = available
            var received: [Bool] = []
            sut.viewModel.loadedAvailability = { received.append($0) }

            sut.viewModel.appear()

            XCTAssertEqual(received, [available])
        }
    }

    func test_appear_deliversMoodWithLabelOfLoadedFacts() {
        let sut = makeSUT()
        var received: [PlantChatMoodViewModel] = []
        sut.viewModel.loadedMood = { received.append($0) }

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .veryThirsty))

        XCTAssertEqual(received.map(\.mood), [.veryThirsty])
        XCTAssertEqual(received.map(\.label), ["Very thirsty"])
    }

    func test_factsUpdate_deliversMoodLive() {
        let sut = makeSUT()
        var received: [PlantMood] = []
        sut.viewModel.loadedMood = { received.append($0.mood) }

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .happy))
        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .tooCold), at: 1)

        XCTAssertEqual(received, [.happy, .tooCold])
    }

    func test_factsLoadFailure_doesNotDeliverMood() {
        let sut = makeSUT()
        var received: [PlantMood] = []
        sut.viewModel.loadedMood = { received.append($0.mood) }

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: anyNSError())

        XCTAssertEqual(received, [])
    }

    // MARK: - greeting

    func test_appear_asksForGreetingLineWithLoadedFacts() {
        let sut = makeSUT()
        let facts = makeFacts()

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: facts)

        XCTAssertEqual(sut.lineLoader.requests, [PlantVoiceLineRequest(facts: facts, purpose: .greeting)])
    }

    func test_greeting_deliversGeneratedLineFromPlant() {
        let sut = makeSUT()
        var received: [[PlantChatMessageViewModel]] = []
        sut.viewModel.loadedMessages = { received.append($0) }

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts())
        XCTAssertEqual(received, [])
        sut.lineLoader.complete(with: "Hello, human!")

        XCTAssertEqual(received.map { $0.map(\.text) }, [["Hello, human!"]])
        XCTAssertEqual(received.last?.map(\.sender), [.plant])
    }

    func test_greeting_usesTemplateWhenLineFails() {
        let sut = makeSUT()
        var received: [[PlantChatMessageViewModel]] = []
        sut.viewModel.loadedMessages = { received.append($0) }

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts())
        sut.lineLoader.complete(with: anyNSError())

        XCTAssertEqual(received.last?.map(\.text), [String.localised(key: "plant.chat.greeting.speech")])
    }

    func test_greeting_usesTemplateWhenFactsFail() {
        let sut = makeSUT()
        var received: [[PlantChatMessageViewModel]] = []
        sut.viewModel.loadedMessages = { received.append($0) }

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: anyNSError())

        XCTAssertEqual(sut.lineLoader.requests, [])
        XCTAssertEqual(received.last?.map(\.text), [String.localised(key: "plant.chat.greeting.speech")])
    }

    func test_greeting_isRequestedOnlyAfterFactsLoad() {
        let sut = makeSUT()
        let facts = makeFacts(mood: .tooHot)

        sut.viewModel.appear()
        XCTAssertEqual(sut.lineLoader.requests, [])
        sut.factsLoader.completeLoad(with: facts)

        XCTAssertEqual(sut.lineLoader.requests, [PlantVoiceLineRequest(facts: facts, purpose: .greeting)])
    }

    func test_select_loadsFreshFactsBeforeAskingForGreeting() {
        let sut = makeLoadedSUT(facts: makeFacts(mood: .thirsty))
        let fresh = makeFacts(mood: .tooCold)

        sut.viewModel.select(.dramatic)
        XCTAssertEqual(sut.lineLoader.requests.count, 1)
        sut.factsLoader.completeLoad(with: fresh, at: 1)

        XCTAssertEqual(sut.factsLoader.messages, [.subscribeFacts, .loadFacts, .loadFacts])
        XCTAssertEqual(sut.lineLoader.requests.last, PlantVoiceLineRequest(facts: fresh, purpose: .greeting))
    }

    func test_greeting_usesTemplateWhenMoodChangesDuringGeneration() {
        let sut = makeSUT()
        var messages: [[PlantChatMessageViewModel]] = []
        sut.viewModel.loadedMessages = { messages.append($0) }

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .thirsty))
        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .happy), at: 1)
        sut.lineLoader.complete(with: "I am so thirsty!")

        XCTAssertEqual(messages.last?.map(\.text), [String.localised(key: "plant.chat.greeting.speech")])
    }

    // MARK: - reopen

    func test_reopen_keepsConversationWithSameMoodWithinThirtyMinutes() {
        var now = anyDate()
        let sut = makeSUT(currentDate: { now })
        var messages: [[PlantChatMessageViewModel]] = []
        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .thirsty))
        sut.lineLoader.complete(with: "Hey!")
        sut.viewModel.loadedMessages = { messages.append($0) }

        now = now.addingTimeInterval(30 * 60)
        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .thirsty), at: 1)

        XCTAssertEqual(messages, [])
        XCTAssertEqual(sut.lineLoader.requests.count, 1)
        XCTAssertEqual(sut.chatLoader.resetCount, 0)
    }

    func test_reopen_startsFreshWhenMoodChanged() {
        let sut = makeSUT()
        var messages: [[PlantChatMessageViewModel]] = []
        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .thirsty))
        sut.lineLoader.complete(with: "Hey!")
        sut.viewModel.loadedMessages = { messages.append($0) }

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .tooHot), at: 1)
        sut.factsLoader.completeLoad(with: makeFacts(mood: .tooHot), at: 2)
        sut.lineLoader.complete(with: "Hot!", at: 1)

        XCTAssertEqual(sut.chatLoader.resetCount, 1)
        XCTAssertEqual(messages.map { $0.map(\.text) }, [[], ["Hot!"]])
    }

    func test_reopen_startsFreshAfterThirtyMinutesAndOneSecond() {
        var now = anyDate()
        let sut = makeSUT(currentDate: { now })
        var messages: [[PlantChatMessageViewModel]] = []
        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts())
        sut.lineLoader.complete(with: "Hey!")
        sut.viewModel.loadedMessages = { messages.append($0) }

        now = now.addingTimeInterval(30 * 60 + 1)
        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts(), at: 1)
        sut.factsLoader.completeLoad(with: makeFacts(), at: 2)
        sut.lineLoader.complete(with: "Welcome back!", at: 1)

        XCTAssertEqual(sut.chatLoader.resetCount, 1)
        XCTAssertEqual(messages.map { $0.map(\.text) }, [[], ["Welcome back!"]])
    }

    func test_reopen_measuresTimeFromLastMessage() {
        var now = anyDate()
        let sut = makeSUT(currentDate: { now })
        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts())
        sut.lineLoader.complete(with: "Hey!")
        now = now.addingTimeInterval(20 * 60)
        sut.viewModel.send("Hi")
        sut.chatLoader.complete(with: "Hello")

        now = now.addingTimeInterval(20 * 60)
        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts(), at: 1)

        XCTAssertEqual(sut.chatLoader.resetCount, 0)
    }

    func test_reopen_dropsReplyStillInFlight() {
        let sut = makeLoadedSUT(facts: makeFacts(mood: .thirsty))
        var messages: [[PlantChatMessageViewModel]] = []
        var typing: [Bool] = []
        sut.viewModel.send("Hi")
        sut.viewModel.loadedMessages = { messages.append($0) }
        sut.viewModel.loadedTyping = { typing.append($0) }

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .tooHot), at: 1)
        sut.chatLoader.complete(with: "Old reply")

        XCTAssertEqual(typing, [false])
        XCTAssertEqual(messages.map { $0.map(\.text) }, [[]])
    }

    // MARK: - send

    func test_send_doesNothingForEmptyOrBlankText() {
        let sut = makeLoadedSUT()
        var typing: [Bool] = []
        sut.viewModel.loadedTyping = { typing.append($0) }

        ["", "   ", "\n\t "].forEach { sut.viewModel.send($0) }

        XCTAssertEqual(sut.chatLoader.sends, [])
        XCTAssertEqual(typing, [])
    }

    func test_send_passesTrimmedTextAndLatestFactsToChatLoader() {
        let sut = makeLoadedSUT()
        let latest = makeFacts(mood: .tooHot)
        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: latest, at: 1)

        sut.viewModel.send("  How are you?\n")

        XCTAssertEqual(sut.chatLoader.sends, [.init(text: "How are you?", facts: latest)])
    }

    func test_send_addsUserMessageAndTypingThenReply() {
        let sut = makeLoadedSUT()
        var messages: [[PlantChatMessageViewModel]] = []
        var typing: [Bool] = []
        sut.viewModel.loadedMessages = { messages.append($0) }
        sut.viewModel.loadedTyping = { typing.append($0) }

        sut.viewModel.send("Hi")

        XCTAssertEqual(messages.last?.map(\.text), ["Hey!", "Hi"])
        XCTAssertEqual(messages.last?.map(\.sender), [.plant, .user])
        XCTAssertEqual(typing, [true])

        sut.chatLoader.complete(with: "Hello yourself")

        XCTAssertEqual(messages.last?.map(\.text), ["Hey!", "Hi", "Hello yourself"])
        XCTAssertEqual(messages.last?.map(\.sender), [.plant, .user, .plant])
        XCTAssertEqual(typing, [true, false])
    }

    func test_send_givesMessagesUniqueIDs() {
        let sut = makeLoadedSUT()
        var messages: [PlantChatMessageViewModel] = []
        sut.viewModel.loadedMessages = { messages = $0 }

        sut.viewModel.send("One")
        sut.chatLoader.complete(with: "Two")

        XCTAssertEqual(Set(messages.map(\.id)).count, 3)
    }

    func test_send_ignoresSendsWhileReplyIsPending() {
        let sut = makeLoadedSUT()

        sut.viewModel.send("One")
        sut.viewModel.send("Two")

        XCTAssertEqual(sut.chatLoader.sends.map(\.text), ["One"])
    }

    func test_send_acceptsNextSendAfterReply() {
        let sut = makeLoadedSUT()

        sut.viewModel.send("One")
        sut.chatLoader.complete(with: "Reply")
        sut.viewModel.send("Two")

        XCTAssertEqual(sut.chatLoader.sends.map(\.text), ["One", "Two"])
    }

    func test_send_repliesWithTemplateAndValuesWhenChatFails() {
        let sut = makeLoadedSUT(facts: makeFacts(mood: .thirsty, reading: makeReading(moisture: 24, lux: 1_200, temperature: 21, humidity: 55)))
        var messages: [PlantChatMessageViewModel] = []
        sut.viewModel.loadedMessages = { messages = $0 }

        sut.viewModel.send("Hi")
        sut.chatLoader.complete(with: anyNSError())

        XCTAssertEqual(
            messages.last?.text,
            "I could use a drink soon. Right now: moisture 24%, light 1,200 lx, temperature 21.0 °C, humidity 55%."
        )
        XCTAssertEqual(messages.last?.sender, .plant)
    }

    func test_fallbackReply_leavesOutNilValues() {
        let sut = makeLoadedSUT(facts: makeFacts(mood: .tooDark, reading: makeReading(moisture: 40, lux: 3, temperature: nil, humidity: nil)))
        var messages: [PlantChatMessageViewModel] = []
        sut.viewModel.loadedMessages = { messages = $0 }

        sut.viewModel.send("Hi")
        sut.chatLoader.complete(with: anyNSError())

        XCTAssertEqual(messages.last?.text, "It's a bit dark in here. Right now: moisture 40%, light 3 lx.")
    }

    func test_fallbackReply_saysNoReadingsWithoutReading() {
        let sut = makeLoadedSUT(facts: PlantVoiceFacts(mood: .offline, isSleeping: false, reading: nil))
        var messages: [PlantChatMessageViewModel] = []
        sut.viewModel.loadedMessages = { messages = $0 }

        sut.viewModel.send("Hi")
        sut.chatLoader.complete(with: anyNSError())

        XCTAssertEqual(messages.last?.text, "Zzz… I can't feel my sensor. I don't have any readings yet.")
    }

    func test_send_repliesWithTemplateWithoutAskingChatLoaderWhenFactsNeverLoaded() {
        let sut = makeSUT()
        var messages: [PlantChatMessageViewModel] = []
        sut.viewModel.loadedMessages = { messages = $0 }

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: anyNSError())
        sut.viewModel.send("Hi")

        XCTAssertEqual(sut.chatLoader.sends, [])
        XCTAssertEqual(messages.last?.text, String.localised(key: "plant.chat.reply.unknown"))
    }

    // MARK: - select

    func test_select_savesPersonalityAndResetsChatLoader() {
        let sut = makeLoadedSUT()

        sut.viewModel.select(.politeButler)

        XCTAssertEqual(sut.settings.load(), .politeButler)
        XCTAssertEqual(sut.chatLoader.resetCount, 1)
    }

    func test_select_deliversPersonalityClearsMessagesAndGreetsAgain() {
        let sut = makeLoadedSUT()
        var personalities: [PlantPersonality] = []
        var messages: [[PlantChatMessageViewModel]] = []
        sut.viewModel.loadedPersonality = { personalities.append($0) }
        sut.viewModel.loadedMessages = { messages.append($0) }

        sut.viewModel.select(.politeButler)
        sut.factsLoader.completeLoad(with: makeFacts(), at: 1)
        XCTAssertEqual(sut.lineLoader.requests.count, 2)
        sut.lineLoader.complete(with: "Good day.", at: 1)

        XCTAssertEqual(personalities, [.politeButler])
        XCTAssertEqual(messages.map { $0.map(\.text) }, [[], ["Good day."]])
    }

    func test_select_dropsPendingReplyOfOldConversation() {
        let sut = makeLoadedSUT()
        var messages: [[PlantChatMessageViewModel]] = []
        var typing: [Bool] = []

        sut.viewModel.send("Hi")
        sut.viewModel.loadedMessages = { messages.append($0) }
        sut.viewModel.loadedTyping = { typing.append($0) }
        sut.viewModel.select(.dramatic)
        sut.chatLoader.complete(with: "Old reply")

        XCTAssertEqual(typing, [false])
        XCTAssertEqual(messages.map { $0.map(\.text) }, [[]])
    }

    func test_select_dropsGreetingOfOldConversation() {
        let sut = makeSUT()
        var messages: [[PlantChatMessageViewModel]] = []
        sut.viewModel.loadedMessages = { messages.append($0) }

        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts())
        sut.viewModel.select(.dramatic)
        sut.lineLoader.complete(with: "Old greeting", at: 0)
        sut.factsLoader.completeLoad(with: makeFacts(), at: 1)
        sut.lineLoader.complete(with: "New greeting", at: 1)

        XCTAssertEqual(messages.map { $0.map(\.text) }, [[], ["New greeting"]])
    }

    func test_select_allowsSendingAfterReset() {
        let sut = makeLoadedSUT()

        sut.viewModel.send("One")
        sut.viewModel.select(.chillSurfer)
        sut.viewModel.send("Two")

        XCTAssertEqual(sut.chatLoader.sends.map(\.text), ["One", "Two"])
    }

    // MARK: - back

    func test_backTap_deliversBackTapAction() {
        var actions: [PlantChatAction] = []
        let sut = makeSUT(actionHandler: { actions.append($0) })

        sut.viewModel.backTap()

        XCTAssertEqual(actions, [.backTap])
    }

    // MARK: - voice: appear

    func test_appear_withEachAuthorization_deliversInputModeAndNotice() {
        let cases: [(PlantSpeechAuthorization, PlantChatInputMode?, Bool)] = [
            (.authorized, nil, false),
            (.notDetermined, nil, false),
            (.denied, .keyboard, true),
            (.restricted, .keyboard, true),
            (.unsupported, .keyboard, true)
        ]
        for (authorization, mode, hasNotice) in cases {
            let sut = makeSUT(authorization: authorization)
            var modes: [PlantChatInputMode] = []
            var notices: [PlantChatMicrophoneNoticeViewModel?] = []
            sut.viewModel.loadedInputMode = { modes.append($0) }
            sut.viewModel.loadedMicrophoneNotice = { notices.append($0) }

            sut.viewModel.appear()

            XCTAssertEqual(modes, mode.map { [$0] } ?? [], "\(authorization)")
            XCTAssertEqual(notices.compactMap { $0 }.count, hasNotice ? 1 : 0, "\(authorization)")
        }
    }

    func test_appear_preparesTranscriptOnceAndSubscribesToAudioSession() {
        let sut = makeSUT()

        sut.viewModel.appear()
        sut.viewModel.appear()

        XCTAssertEqual(sut.transcriptLoader.messages, [.prepare])
        XCTAssertEqual(sut.audioSession.messages, [.subscribe])
    }

    // MARK: - voice: micTap

    func test_micTap_whenNotDetermined_requestsAuthorization() {
        let sut = makeLoadedSUT(authorization: .notDetermined)

        sut.viewModel.micTap()

        XCTAssertEqual(sut.transcriptLoader.messages, [.prepare, .requestAuthorization])
        XCTAssertEqual(sut.audioSession.messages, [.subscribe])
    }

    func test_micTap_whenAuthorizationIsGranted_startsListening() {
        let sut = makeLoadedSUT(authorization: .notDetermined)
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.viewModel.micTap()
        sut.transcriptLoader.completeAuthorization(with: .authorized)

        XCTAssertEqual(sut.audioSession.messages, [.subscribe, .activate])
        XCTAssertEqual(sut.transcriptLoader.messages, [.prepare, .requestAuthorization, .start])
        XCTAssertEqual(activities, [.listening])
    }

    func test_micTap_whenAuthorizationIsDenied_showsNoticeWithSettingsAndKeyboardMode() {
        let sut = makeLoadedSUT(authorization: .notDetermined)
        var modes: [PlantChatInputMode] = []
        var notices: [PlantChatMicrophoneNoticeViewModel?] = []
        let viewModel = sut.viewModel
        viewModel.loadedInputMode = { modes.append($0) }
        viewModel.loadedMicrophoneNotice = { notices.append($0) }

        viewModel.micTap()
        sut.transcriptLoader.completeAuthorization(with: .denied)

        XCTAssertEqual(modes, [.keyboard])
        XCTAssertEqual(notices.compactMap { $0 }.count, 1)
        XCTAssertNotNil(notices.compactMap { $0 }.first?.settingsLabel)
        XCTAssertEqual(sut.transcriptLoader.messages, [.prepare, .requestAuthorization])
    }

    func test_micTap_whenAuthorized_activatesThenStartsListening() {
        let sut = makeLoadedSUT()
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.viewModel.micTap()

        XCTAssertEqual(sut.audioSession.messages, [.subscribe, .activate])
        XCTAssertEqual(sut.transcriptLoader.messages, [.prepare, .start])
        XCTAssertEqual(activities, [.listening])
    }

    func test_micTap_whenActivationFails_showsNoticeAndDoesNotStart() {
        let sut = makeLoadedSUT()
        sut.audioSession.canActivate = false
        var notices: [PlantChatMicrophoneNoticeViewModel?] = []
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedMicrophoneNotice = { notices.append($0) }
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.viewModel.micTap()

        XCTAssertEqual(sut.transcriptLoader.messages, [.prepare])
        XCTAssertEqual(notices.compactMap { $0 }.count, 1)
        XCTAssertEqual(activities, [])
    }

    func test_micTap_whileListening_stopsTranscriptLoader() {
        let sut = makeListeningSUT()

        sut.viewModel.micTap()

        XCTAssertEqual(sut.transcriptLoader.messages.last, .stop)
    }

    func test_micTap_whileThinking_isIgnored() {
        let sut = makeListeningSUT()
        sut.transcriptLoader.sendFinal("Hi")
        let audioMessages = sut.audioSession.messages
        let transcriptMessages = sut.transcriptLoader.messages

        sut.viewModel.micTap()

        XCTAssertEqual(sut.audioSession.messages, audioMessages)
        XCTAssertEqual(sut.transcriptLoader.messages, transcriptMessages)
    }

    // MARK: - voice: transcripts

    func test_partialTranscript_deliversLiveText() {
        let sut = makeListeningSUT()
        var received: [String] = []
        sut.viewModel.loadedTranscript = { received.append($0) }

        sut.transcriptLoader.sendPartial("Am I")
        sut.transcriptLoader.sendPartial("Am I thirsty")

        XCTAssertEqual(received, ["Am I", "Am I thirsty"])
    }

    func test_finalTranscript_sendsLikeATypedSendAndThinks() {
        let facts = makeFacts()
        let sut = makeListeningSUT(facts: facts)
        var activities: [PlantChatActivity] = []
        var transcripts: [String] = []
        var messages: [[PlantChatMessageViewModel]] = []
        sut.viewModel.loadedActivity = { activities.append($0) }
        sut.viewModel.loadedTranscript = { transcripts.append($0) }
        sut.viewModel.loadedMessages = { messages.append($0) }

        sut.transcriptLoader.sendFinal("  Am I thirsty? ")

        XCTAssertEqual(sut.chatLoader.sends, [.init(text: "Am I thirsty?", facts: facts)])
        XCTAssertEqual(messages.last?.map(\.text), ["Hey!", "Am I thirsty?"])
        XCTAssertEqual(transcripts, [""])
        XCTAssertEqual(activities, [.thinking])
        XCTAssertEqual(sut.audioSession.messages.last, .activate)
    }

    func test_emptyFinalTranscript_goesIdleDeactivatesAndSendsNothing() {
        let sut = makeListeningSUT()
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.transcriptLoader.sendFinal("  ")

        XCTAssertEqual(activities, [.idle])
        XCTAssertEqual(sut.audioSession.messages.last, .deactivate)
        XCTAssertEqual(sut.chatLoader.sends, [])
    }

    func test_transcriptFailure_goesIdleDeactivatesAndShowsNotice() {
        let errors: [TranscriberPlantTranscriptLoader.Error] = [.preparing, .transcription]
        var texts: [String] = []
        for error in errors {
            let sut = makeListeningSUT()
            var activities: [PlantChatActivity] = []
            var notices: [PlantChatMicrophoneNoticeViewModel?] = []
            sut.viewModel.loadedActivity = { activities.append($0) }
            sut.viewModel.loadedMicrophoneNotice = { notices.append($0) }

            sut.transcriptLoader.send(error)

            XCTAssertEqual(activities, [.idle])
            XCTAssertEqual(sut.audioSession.messages.last, .deactivate)
            XCTAssertEqual(sut.chatLoader.sends, [])
            texts.append(notices.compactMap { $0 }.first?.text ?? "")
        }
        XCTAssertFalse(texts[0].isEmpty)
        XCTAssertNotEqual(texts[0], texts[1])
    }

    func test_interruptionOrLostOutput_whileListening_cancelsAndGoesIdle() {
        for event in [PlantAudioSessionEvent.interruptionBegan, .outputDeviceLost] {
            let sut = makeListeningSUT()
            var activities: [PlantChatActivity] = []
            var transcripts: [String] = []
            sut.viewModel.loadedActivity = { activities.append($0) }
            sut.viewModel.loadedTranscript = { transcripts.append($0) }

            sut.audioSession.simulate(event)

            XCTAssertEqual(sut.transcriptLoader.messages.last, .cancel)
            XCTAssertEqual(sut.audioSession.messages.last, .deactivate)
            XCTAssertEqual(activities, [.idle])
            XCTAssertEqual(transcripts, [""])
            XCTAssertEqual(sut.chatLoader.sends, [])
        }
    }

    func test_transcriptAfterCancel_isIgnored() {
        let sut = makeListeningSUT()
        sut.audioSession.simulate(.interruptionBegan)

        sut.transcriptLoader.sendFinal("Late")

        XCTAssertEqual(sut.chatLoader.sends, [])
    }

    func test_interruption_whileThinking_deactivates() {
        let sut = makeListeningSUT()
        sut.transcriptLoader.sendFinal("Hi")

        sut.audioSession.simulate(.interruptionBegan)

        XCTAssertEqual(sut.audioSession.messages.last, .deactivate)
    }

    // MARK: - voice: ending

    func test_endTap_whileListening_cancelsDeactivatesAndGoesBack() {
        var actions: [PlantChatAction] = []
        let sut = makeListeningSUT(actionHandler: { actions.append($0) })
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.viewModel.endTap()

        XCTAssertEqual(sut.transcriptLoader.messages.last, .cancel)
        XCTAssertEqual(sut.audioSession.messages.last, .deactivate)
        XCTAssertEqual(activities, [.idle])
        XCTAssertEqual(actions, [.backTap])
    }

    func test_disappear_whileListening_cancelsAndDeactivates() {
        let sut = makeListeningSUT()
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.viewModel.disappear()

        XCTAssertEqual(sut.transcriptLoader.messages.last, .cancel)
        XCTAssertEqual(sut.audioSession.messages.last, .deactivate)
        XCTAssertEqual(activities, [.idle])
    }

    func test_disappear_whenIdle_doesNotTouchAudio() {
        let sut = makeLoadedSUT()

        sut.viewModel.disappear()

        XCTAssertEqual(sut.transcriptLoader.messages, [.prepare])
        XCTAssertEqual(sut.audioSession.messages, [.subscribe])
    }

    func test_selectPersonality_whileListening_cancelsListening() {
        let sut = makeListeningSUT()

        sut.viewModel.select(.dramatic)

        XCTAssertEqual(sut.transcriptLoader.messages.last, .cancel)
        XCTAssertEqual(sut.audioSession.messages.last, .deactivate)
    }

    func test_typedSend_goesThinkingThenIdleWithoutActivatingAudio() {
        let sut = makeLoadedSUT()
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.viewModel.send("Hi")
        sut.chatLoader.complete(with: "Hello!")

        XCTAssertEqual(activities, [.thinking, .idle])
        XCTAssertEqual(sut.audioSession.messages, [.subscribe])
    }

    // MARK: - voice: input mode

    func test_keyboardTap_deliversKeyboardModeAndCancelsListening() {
        let sut = makeListeningSUT()
        var modes: [PlantChatInputMode] = []
        sut.viewModel.loadedInputMode = { modes.append($0) }

        sut.viewModel.keyboardTap()

        XCTAssertEqual(modes, [.keyboard])
        XCTAssertEqual(sut.transcriptLoader.messages.last, .cancel)
    }

    func test_voiceTap_whenAuthorized_deliversVoiceModeAndClearsNotice() {
        let sut = makeLoadedSUT()
        var modes: [PlantChatInputMode] = []
        var notices: [PlantChatMicrophoneNoticeViewModel?] = []
        sut.viewModel.loadedInputMode = { modes.append($0) }
        sut.viewModel.loadedMicrophoneNotice = { notices.append($0) }

        sut.viewModel.voiceTap()

        XCTAssertEqual(modes, [.voice])
        XCTAssertEqual(notices.count, 1)
        XCTAssertNil(notices[0])
    }

    func test_voiceTap_whenDenied_staysInKeyboardModeWithNotice() {
        let sut = makeLoadedSUT(authorization: .denied)
        var modes: [PlantChatInputMode] = []
        var notices: [PlantChatMicrophoneNoticeViewModel?] = []
        sut.viewModel.loadedInputMode = { modes.append($0) }
        sut.viewModel.loadedMicrophoneNotice = { notices.append($0) }

        sut.viewModel.voiceTap()

        XCTAssertEqual(modes, [.keyboard])
        XCTAssertEqual(notices.compactMap { $0 }.count, 1)
    }

    func test_init_providesVoiceLabels() {
        let sut = makeSUT()

        XCTAssertEqual(sut.viewModel.listeningLabel, "Listening…")
        XCTAssertEqual(sut.viewModel.stopListeningLabel, "Stop listening")
        XCTAssertEqual(sut.viewModel.talkLabel, "Talk to Sprout")
    }

    // MARK: - voice: spoken replies

    func test_reply_toSpokenTurn_isSpokenCleanedWithPersonalityStyleThenIdleWhenFinished() {
        let sut = makeSpokenTurnSUT(personality: .politeButler)
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.chatLoader.complete(with: "*sighs* Water, please 🌱")

        XCTAssertEqual(sut.synthesizer.speeches, [.init(text: "Water, please", style: PlantPersonality.politeButler.speechStyle.adjusted(for: .happy))])
        XCTAssertEqual(activities, [.speaking])
        XCTAssertEqual(sut.audioSession.messages.filter { $0 == .deactivate }.count, 0)

        sut.synthesizer.finish()

        XCTAssertEqual(activities, [.speaking, .idle])
        XCTAssertEqual(sut.audioSession.messages.last, .deactivate)
    }

    func test_reply_toSpokenTurn_whileThirsty_isSpokenWithTheMoodAdjustedStyle() {
        let sut = makeSpokenTurnSUT(personality: .politeButler, mood: .thirsty)

        sut.chatLoader.complete(with: "Water, please")

        XCTAssertEqual(sut.synthesizer.speeches, [.init(text: "Water, please", style: PlantPersonality.politeButler.speechStyle.adjusted(for: .thirsty))])
    }

    func test_reply_toSpokenTurn_showsTheOriginalTextEvenWhenSpoken() {
        let sut = makeSpokenTurnSUT()
        var messages: [[PlantChatMessageViewModel]] = []
        sut.viewModel.loadedMessages = { messages.append($0) }

        sut.chatLoader.complete(with: "*sighs* Hi")

        XCTAssertEqual(messages.last?.last?.text, "*sighs* Hi")
    }

    func test_templateFallbackReply_toSpokenTurn_isSpoken() {
        let sut = makeSpokenTurnSUT()

        sut.chatLoader.complete(with: anyNSError())

        XCTAssertEqual(sut.synthesizer.speeches.count, 1)
        XCTAssertFalse(sut.synthesizer.speeches[0].text.isEmpty)
    }

    func test_reply_withSpokenRepliesOff_isNotSpoken() {
        let sut = makeLoadedSUT()
        sut.viewModel.setSpokenReplies(false)
        sut.viewModel.micTap()
        sut.transcriptLoader.sendFinal("Hi")
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.chatLoader.complete(with: "Hello!")

        XCTAssertEqual(sut.synthesizer.speeches, [])
        XCTAssertEqual(activities, [.idle])
        XCTAssertEqual(sut.audioSession.messages.last, .deactivate)
    }

    func test_reply_toTypedTurn_isNeverSpoken() {
        let sut = makeLoadedSUT()

        sut.viewModel.send("Hi")
        sut.chatLoader.complete(with: "Hello!")

        XCTAssertEqual(sut.synthesizer.speeches, [])
        XCTAssertEqual(sut.audioSession.messages, [.subscribe])
    }

    func test_greeting_isNeverSpoken() {
        let sut = makeLoadedSUT()

        XCTAssertEqual(sut.synthesizer.speeches, [])
    }

    func test_reply_thatCleansToNothing_isNotSpoken() {
        let sut = makeSpokenTurnSUT()
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.chatLoader.complete(with: "🌱 **")

        XCTAssertEqual(sut.synthesizer.speeches, [])
        XCTAssertEqual(activities, [.idle])
    }

    func test_micTap_whileSpeaking_stopsSpeechThenListensWithoutReactivatingOrDeactivating() {
        let sut = makeSpokenTurnSUT()
        sut.chatLoader.complete(with: "Hello!")
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.viewModel.micTap()

        XCTAssertEqual(sut.synthesizer.stopCount, 1)
        XCTAssertEqual(sut.transcriptLoader.messages.last, .start)
        XCTAssertEqual(activities, [.listening])
        XCTAssertEqual(sut.audioSession.messages.filter { $0 == .activate }.count, 1)
        XCTAssertEqual(sut.audioSession.messages.filter { $0 == .deactivate }.count, 0)
    }

    func test_speechCompletion_afterItWasCutOff_isIgnored() {
        let sut = makeSpokenTurnSUT()
        sut.chatLoader.complete(with: "Hello!")
        sut.viewModel.micTap()
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.synthesizer.finish()

        XCTAssertEqual(activities, [])
        XCTAssertEqual(sut.audioSession.messages.filter { $0 == .deactivate }.count, 0)
    }

    func test_interruptionOrLostOutput_whileSpeaking_stopsSpeechDeactivatesAndGoesIdle() {
        for event in [PlantAudioSessionEvent.interruptionBegan, .outputDeviceLost] {
            let sut = makeSpokenTurnSUT()
            sut.chatLoader.complete(with: "Hello!")
            var activities: [PlantChatActivity] = []
            sut.viewModel.loadedActivity = { activities.append($0) }

            sut.audioSession.simulate(event)
            sut.synthesizer.finish()

            XCTAssertEqual(sut.synthesizer.stopCount, 1, "\(event)")
            XCTAssertEqual(sut.audioSession.messages.last, .deactivate, "\(event)")
            XCTAssertEqual(activities, [.idle], "\(event)")
        }
    }

    func test_interruption_whileThinking_showsTheReplyButDoesNotSpeakIt() {
        let sut = makeSpokenTurnSUT()
        var messages: [[PlantChatMessageViewModel]] = []
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedMessages = { messages.append($0) }
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.audioSession.simulate(.interruptionBegan)
        sut.chatLoader.complete(with: "Hello!")

        XCTAssertEqual(messages.last?.last?.text, "Hello!")
        XCTAssertEqual(sut.synthesizer.speeches, [])
        XCTAssertEqual(activities, [.idle])
    }

    func test_interruption_whileThinking_doesNotMuteTheNextSpokenTurn() {
        let sut = makeSpokenTurnSUT()
        sut.audioSession.simulate(.interruptionBegan)
        sut.chatLoader.complete(with: "Hello!")
        sut.viewModel.micTap()
        sut.transcriptLoader.sendFinal("Again", at: 1)

        sut.chatLoader.complete(with: "Hi again!", at: 1)

        XCTAssertEqual(sut.synthesizer.speeches.map(\.text), ["Hi again!"])
    }

    func test_setSpokenReplies_savesAndDelivers() {
        let sut = makeLoadedSUT()
        var received: [Bool] = []
        sut.viewModel.loadedSpokenReplies = { received.append($0) }

        sut.viewModel.setSpokenReplies(false)
        sut.viewModel.setSpokenReplies(true)

        XCTAssertEqual(received, [false, true])
        XCTAssertTrue(sut.defaults.messages.contains(.setBool(false, forKey: "plant.chat.spokenReplies.enabled")))
        XCTAssertEqual(sut.defaults.messages.last, .setBool(true, forKey: "plant.chat.spokenReplies.enabled"))
    }

    func test_appear_deliversSavedSpokenRepliesSetting() {
        let sut = makeSUT()
        sut.defaults.stub(false, forKey: "plant.chat.spokenReplies.enabled")
        var received: [Bool] = []
        sut.viewModel.loadedSpokenReplies = { received.append($0) }

        sut.viewModel.appear()

        XCTAssertEqual(received, [false])
    }

    func test_setSpokenReplies_off_whileSpeaking_stopsSpeechAndGoesIdle() {
        let sut = makeSpokenTurnSUT()
        sut.chatLoader.complete(with: "Hello!")
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.viewModel.setSpokenReplies(false)

        XCTAssertEqual(sut.synthesizer.stopCount, 1)
        XCTAssertEqual(sut.audioSession.messages.last, .deactivate)
        XCTAssertEqual(activities, [.idle])
    }

    func test_setSpokenReplies_off_whileThinking_doesNotSpeakTheReply() {
        let sut = makeSpokenTurnSUT()

        sut.viewModel.setSpokenReplies(false)
        sut.chatLoader.complete(with: "Hello!")

        XCTAssertEqual(sut.synthesizer.speeches, [])
    }

    func test_endTap_whileSpeaking_stopsSpeechDeactivatesAndGoesBack() {
        var actions: [PlantChatAction] = []
        let sut = makeSpokenTurnSUT(actionHandler: { actions.append($0) })
        sut.chatLoader.complete(with: "Hello!")

        sut.viewModel.endTap()

        XCTAssertEqual(sut.synthesizer.stopCount, 1)
        XCTAssertEqual(sut.audioSession.messages.last, .deactivate)
        XCTAssertEqual(actions, [.backTap])
    }

    func test_disappear_whileThinking_showsTheReplyButDoesNotSpeakIt() {
        let sut = makeSpokenTurnSUT()

        sut.viewModel.disappear()
        sut.chatLoader.complete(with: "Hello!")

        XCTAssertEqual(sut.synthesizer.speeches, [])
    }

    func test_selectPersonality_whileSpeaking_stopsSpeech() {
        let sut = makeSpokenTurnSUT()
        sut.chatLoader.complete(with: "Hello!")
        var activities: [PlantChatActivity] = []
        sut.viewModel.loadedActivity = { activities.append($0) }

        sut.viewModel.select(.dramatic)

        XCTAssertEqual(sut.synthesizer.stopCount, 1)
        XCTAssertEqual(activities, [.idle])
    }

    func test_init_providesInterruptAndSpeakRepliesLabels() {
        let sut = makeSUT()

        XCTAssertEqual(sut.viewModel.interruptLabel, "Interrupt Sprout")
        XCTAssertEqual(sut.viewModel.speakRepliesLabel, "Speak replies")
    }

    // MARK: - memory

    func test_appear_doesNotDeliverAfterSUTIsReleased() {
        let factsLoader = FactsLoaderStub()
        let settings = PlantPersonalitySettings(defaults: DefaultsSpy())
        var sut: PlantChatViewModel? = PlantChatViewModel(
            chatLoader: ChatLoaderStub(),
            lineLoader: LineLoaderStub(),
            factsLoader: factsLoader,
            settings: settings,
            transcriptLoader: TranscriptLoaderStub(),
            audioSession: AudioSessionSpy(),
            synthesizer: SynthesizerSpy(),
            spokenReplies: PlantSpokenReplySettings(defaults: DefaultsSpy()),
            plantName: "Sprout",
            actionHandler: { _ in }
        )
        var received: [PlantMood] = []
        sut?.loadedMood = { received.append($0.mood) }

        sut?.appear()
        sut = nil
        factsLoader.completeLoad(with: makeFacts())

        XCTAssertEqual(received, [])
    }

    // MARK: - Private helpers

    private struct SUT {
        let viewModel: PlantChatViewModel
        let chatLoader: ChatLoaderStub
        let lineLoader: LineLoaderStub
        let factsLoader: FactsLoaderStub
        let settings: PlantPersonalitySettings
        let transcriptLoader: TranscriptLoaderStub
        let audioSession: AudioSessionSpy
        let synthesizer: SynthesizerSpy
        let defaults: DefaultsSpy
    }

    private func makeSUT(
        savedPersonality: PlantPersonality? = nil,
        authorization: PlantSpeechAuthorization = .authorized,
        currentDate: @escaping () -> Date = Date.init,
        actionHandler: @escaping (PlantChatAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SUT {
        let chatLoader = ChatLoaderStub()
        let lineLoader = LineLoaderStub()
        let factsLoader = FactsLoaderStub()
        let defaults = DefaultsSpy()
        let settings = PlantPersonalitySettings(defaults: defaults)
        let transcriptLoader = TranscriptLoaderStub()
        transcriptLoader.authorization = authorization
        let audioSession = AudioSessionSpy()
        let synthesizer = SynthesizerSpy()
        let spokenReplies = PlantSpokenReplySettings(defaults: defaults)
        if let savedPersonality {
            settings.save(savedPersonality)
        }
        let viewModel = PlantChatViewModel(
            chatLoader: chatLoader,
            lineLoader: lineLoader,
            factsLoader: factsLoader,
            settings: settings,
            transcriptLoader: transcriptLoader,
            audioSession: audioSession,
            synthesizer: synthesizer,
            spokenReplies: spokenReplies,
            plantName: "Sprout",
            currentDate: currentDate,
            actionHandler: actionHandler
        )
        trackMemoryLeak(chatLoader, file: file, line: line)
        trackMemoryLeak(lineLoader, file: file, line: line)
        trackMemoryLeak(factsLoader, file: file, line: line)
        trackMemoryLeak(defaults, file: file, line: line)
        trackMemoryLeak(settings, file: file, line: line)
        trackMemoryLeak(transcriptLoader, file: file, line: line)
        trackMemoryLeak(audioSession, file: file, line: line)
        trackMemoryLeak(synthesizer, file: file, line: line)
        trackMemoryLeak(spokenReplies, file: file, line: line)
        trackMemoryLeak(viewModel, file: file, line: line)
        return SUT(viewModel: viewModel, chatLoader: chatLoader, lineLoader: lineLoader, factsLoader: factsLoader, settings: settings, transcriptLoader: transcriptLoader, audioSession: audioSession, synthesizer: synthesizer, defaults: defaults)
    }

    /// Loaded, then listening.
    private func makeListeningSUT(
        facts: PlantVoiceFacts? = nil,
        actionHandler: @escaping (PlantChatAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SUT {
        let sut = makeSUT(actionHandler: actionHandler, file: file, line: line)
        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: facts ?? makeFacts())
        sut.lineLoader.complete(with: "Hey!")
        sut.viewModel.micTap()
        return sut
    }

    /// Loaded, listened, and a final transcript sent; the reply is pending.
    private func makeSpokenTurnSUT(
        personality: PlantPersonality? = nil,
        mood: PlantMood = .happy,
        actionHandler: @escaping (PlantChatAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SUT {
        let sut = makeSUT(savedPersonality: personality, actionHandler: actionHandler, file: file, line: line)
        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: makeFacts(mood: mood))
        sut.lineLoader.complete(with: "Hey!")
        sut.viewModel.micTap()
        sut.transcriptLoader.sendFinal("Hi")
        return sut
    }

    /// Appeared, with facts loaded and the greeting "Hey!" shown.
    private func makeLoadedSUT(
        facts: PlantVoiceFacts? = nil,
        authorization: PlantSpeechAuthorization = .authorized,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SUT {
        let sut = makeSUT(authorization: authorization, file: file, line: line)
        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: facts ?? makeFacts())
        sut.lineLoader.complete(with: "Hey!")
        return sut
    }
}
