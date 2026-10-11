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

    func test_init_listsEveryPersonalityWithLabel() {
        let sut = makeSUT()

        XCTAssertEqual(sut.viewModel.personalities.map(\.personality), PlantPersonality.allCases)
        XCTAssertEqual(Set(sut.viewModel.personalities.map(\.label)).count, PlantPersonality.allCases.count)
        XCTAssertEqual(sut.viewModel.personalities.first?.label, "Cheerful")
    }

    // MARK: - appear

    func test_appear_subscribesAndLoadsFactsOnce() {
        let sut = makeSUT()

        sut.viewModel.appear()
        sut.viewModel.appear()

        XCTAssertEqual(sut.factsLoader.messages, [.subscribeFacts, .loadFacts])
    }

    func test_appear_deliversSavedPersonality() {
        let sut = makeSUT(savedPersonality: .dramatic)
        var received: [PlantPersonality] = []
        sut.viewModel.loadedPersonality = { received.append($0) }

        sut.viewModel.appear()

        XCTAssertEqual(received, [.dramatic])
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

        sut.viewModel.select(.grumpyGrandma)

        XCTAssertEqual(sut.settings.load(), .grumpyGrandma)
        XCTAssertEqual(sut.chatLoader.resetCount, 1)
    }

    func test_select_deliversPersonalityClearsMessagesAndGreetsAgain() {
        let sut = makeLoadedSUT()
        var personalities: [PlantPersonality] = []
        var messages: [[PlantChatMessageViewModel]] = []
        sut.viewModel.loadedPersonality = { personalities.append($0) }
        sut.viewModel.loadedMessages = { messages.append($0) }

        sut.viewModel.select(.politeButler)
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

    // MARK: - memory

    func test_appear_doesNotDeliverAfterSUTIsReleased() {
        let factsLoader = FactsLoaderStub()
        let settings = PlantPersonalitySettings(defaults: DefaultsSpy())
        var sut: PlantChatViewModel? = PlantChatViewModel(
            chatLoader: ChatLoaderStub(),
            lineLoader: LineLoaderStub(),
            factsLoader: factsLoader,
            settings: settings,
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
    }

    private func makeSUT(
        savedPersonality: PlantPersonality? = nil,
        actionHandler: @escaping (PlantChatAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SUT {
        let chatLoader = ChatLoaderStub()
        let lineLoader = LineLoaderStub()
        let factsLoader = FactsLoaderStub()
        let defaults = DefaultsSpy()
        let settings = PlantPersonalitySettings(defaults: defaults)
        if let savedPersonality {
            settings.save(savedPersonality)
        }
        let viewModel = PlantChatViewModel(
            chatLoader: chatLoader,
            lineLoader: lineLoader,
            factsLoader: factsLoader,
            settings: settings,
            plantName: "Sprout",
            actionHandler: actionHandler
        )
        trackMemoryLeak(chatLoader, file: file, line: line)
        trackMemoryLeak(lineLoader, file: file, line: line)
        trackMemoryLeak(factsLoader, file: file, line: line)
        trackMemoryLeak(defaults, file: file, line: line)
        trackMemoryLeak(settings, file: file, line: line)
        trackMemoryLeak(viewModel, file: file, line: line)
        return SUT(viewModel: viewModel, chatLoader: chatLoader, lineLoader: lineLoader, factsLoader: factsLoader, settings: settings)
    }

    /// Appeared, with facts loaded and the greeting "Hey!" shown.
    private func makeLoadedSUT(
        facts: PlantVoiceFacts? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SUT {
        let sut = makeSUT(file: file, line: line)
        sut.viewModel.appear()
        sut.factsLoader.completeLoad(with: facts ?? makeFacts())
        sut.lineLoader.complete(with: "Hey!")
        return sut
    }
}
