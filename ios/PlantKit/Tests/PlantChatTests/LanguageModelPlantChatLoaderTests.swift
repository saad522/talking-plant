import XCTest
@testable import PlantChat

@MainActor
final class LanguageModelPlantChatLoaderTests: PlantChatXCTestCase {
    func test_init_doesNotMessageClient() {
        let (_, client, _) = makeSUT()

        XCTAssertEqual(client.messages, [])
    }

    func test_isAvailable_followsClientEveryTime() {
        let (sut, client, _) = makeSUT()

        client.isAvailable = false
        XCTAssertFalse(sut.isAvailable)
        client.isAvailable = true
        XCTAssertTrue(sut.isAvailable)
    }

    func test_send_failsAtOnceWithoutSessionWhenModelIsUnavailable() {
        let (sut, client, _) = makeSUT()
        client.isAvailable = false

        expect(sut, toDeliver: .failure(LanguageModelPlantChatLoader.Error.unavailable), when: {})
        XCTAssertEqual(client.messages, [])
    }

    func test_send_createsSessionWithHistoryOnFirstSend() {
        let (sut, client, _) = makeSUT(personality: .chillSurfer)

        sut.send("Hi", facts: makeFacts()) { _ in }

        XCTAssertEqual(client.messages, [.init(
            instructions: PlantVoicePrompt.instructions(personality: .chillSurfer, plantName: "Sprout"),
            canReadHistory: true
        )])
    }

    func test_send_promptsWithCurrentFactsThenMessage() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts()

        sut.send("How thirsty are you?", facts: facts) { _ in }

        XCTAssertEqual(client.sessions[0].prompts, [PlantVoicePrompt.message("How thirsty are you?", facts: facts)])
    }

    func test_send_reusesSessionAcrossSends() {
        let (sut, client, _) = makeSUT()
        let first = makeFacts(mood: .thirsty)
        let second = makeFacts(mood: .happy)

        sut.send("One", facts: first) { _ in }
        sut.send("Two", facts: second) { _ in }

        XCTAssertEqual(client.sessions.count, 1)
        XCTAssertEqual(client.sessions[0].prompts, [
            PlantVoicePrompt.message("One", facts: first),
            PlantVoicePrompt.message("Two", facts: second)
        ])
    }

    func test_send_deliversReplyText() {
        let (sut, client, _) = makeSUT()

        expect(sut, toDeliver: .success("Quite thirsty!"), when: { client.sessions[0].complete(with: "Quite thirsty!") })
    }

    func test_send_deliversGenerationErrorOnSessionFailure() {
        let (sut, client, _) = makeSUT()

        expect(sut, toDeliver: .failure(LanguageModelPlantChatLoader.Error.generation), when: {
            client.sessions[0].complete(with: PlantLanguageModelError.generation)
        })
    }

    func test_send_startsNewSessionWhenPersonalityChanged() {
        let (sut, client, setPersonality) = makeSUT()

        sut.send("One", facts: makeFacts()) { _ in }
        setPersonality(.dramatic)
        sut.send("Two", facts: makeFacts()) { _ in }

        XCTAssertEqual(client.messages.map(\.instructions), [
            PlantVoicePrompt.instructions(personality: .cheerful, plantName: "Sprout"),
            PlantVoicePrompt.instructions(personality: .dramatic, plantName: "Sprout")
        ])
        XCTAssertEqual(client.sessions[1].prompts.count, 1)
    }

    func test_send_retriesOnceWithNewSessionWhenContextIsTooLong() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts()
        var results: [PlantChatLoader.Result] = []

        sut.send("Long story", facts: facts) { results.append($0) }
        client.sessions[0].complete(with: PlantLanguageModelError.contextTooLong)
        client.sessions[1].complete(with: "Short answer")

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(client.sessions[1].prompts, [PlantVoicePrompt.message("Long story", facts: facts)])
        XCTAssertEqual(try? results.first?.get(), "Short answer")
        XCTAssertEqual(results.count, 1)
    }

    func test_send_doesNotRetryASecondTime() {
        let (sut, client, _) = makeSUT()

        expect(sut, toDeliver: .failure(LanguageModelPlantChatLoader.Error.generation), when: {
            client.sessions[0].complete(with: PlantLanguageModelError.contextTooLong)
            client.sessions[1].complete(with: PlantLanguageModelError.contextTooLong)
        })
        XCTAssertEqual(client.sessions.count, 2)
    }

    func test_send_doesNotRetryOtherErrors() {
        let (sut, client, _) = makeSUT()

        expect(sut, toDeliver: .failure(LanguageModelPlantChatLoader.Error.generation), when: {
            client.sessions[0].complete(with: anyNSError())
        })
        XCTAssertEqual(client.sessions.count, 1)
    }

    func test_send_usesTheRetrySessionForLaterSends() {
        let (sut, client, _) = makeSUT()

        sut.send("One", facts: makeFacts()) { _ in }
        client.sessions[0].complete(with: PlantLanguageModelError.contextTooLong)
        client.sessions[1].complete(with: "Ok")
        sut.send("Two", facts: makeFacts()) { _ in }

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(client.sessions[1].prompts.count, 2)
    }

    func test_send_retriesWithNewSessionWhenReplyRepeatsOneOfTheLastReplies() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts()
        var results: [PlantChatLoader.Result] = []

        sut.send("One", facts: facts) { _ in }
        client.sessions[0].complete(with: "I'm fine, thank you.")
        sut.send("Do you need water?", facts: facts) { results.append($0) }
        client.sessions[0].complete(with: "  im FINE thank you ", at: 1)
        client.sessions[1].complete(with: "Not at all, I'm at 24%.")

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(client.sessions[1].prompts, [PlantVoicePrompt.message("Do you need water?", facts: facts)])
        XCTAssertEqual(try? results.first?.get(), "Not at all, I'm at 24%.")
        XCTAssertEqual(results.count, 1)
    }

    func test_send_deliversTemplateWhenReplyRepeatsAgainAfterRetry() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts()
        var results: [PlantChatLoader.Result] = []

        sut.send("One", facts: facts) { _ in }
        client.sessions[0].complete(with: "I'm fine.")
        sut.send("Two", facts: facts) { results.append($0) }
        client.sessions[0].complete(with: "I'm fine!", at: 1)
        client.sessions[1].complete(with: "i'm fine")

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(try? results.first?.get(), PlantChatTemplate.reply(facts: facts))
        XCTAssertEqual(results.count, 1)
    }

    func test_send_doesNotRetryWhenReplyDiffersFromTheLastReplies() {
        let (sut, client, _) = makeSUT()
        var results: [PlantChatLoader.Result] = []

        sut.send("One", facts: makeFacts()) { _ in }
        client.sessions[0].complete(with: "I'm fine.")
        sut.send("Two", facts: makeFacts()) { results.append($0) }
        client.sessions[0].complete(with: "I love the light!", at: 1)

        XCTAssertEqual(client.sessions.count, 1)
        XCTAssertEqual(try? results.first?.get(), "I love the light!")
    }

    func test_send_comparesOnlyWithTheLastThreeReplies() {
        let (sut, client, _) = makeSUT()
        var results: [PlantChatLoader.Result] = []

        ["A", "B", "C", "D"].enumerated().forEach { index, reply in
            sut.send(reply, facts: makeFacts()) { _ in }
            client.sessions[0].complete(with: reply, at: index)
        }
        sut.send("Again", facts: makeFacts()) { results.append($0) }
        client.sessions[0].complete(with: "a", at: 4)

        XCTAssertEqual(client.sessions.count, 1)
        XCTAssertEqual(try? results.first?.get(), "a")
    }

    // MARK: - Reply guard

    func test_send_removesStageDirectionsFromReply() {
        let (sut, client, _) = makeSUT()

        expect(sut, toDeliver: .success("I'm fine, thanks."), when: {
            client.sessions[0].complete(with: "*Grumbles* I'm fine, thanks. (smiles)")
        })
    }

    func test_send_keepsOnlyTheFirstThreeSentences() {
        let (sut, client, _) = makeSUT()

        expect(sut, toDeliver: .success("One. Two! Three?"), when: {
            client.sessions[0].complete(with: "One. Two! Three? Four. Five.")
        })
    }

    func test_send_retriesWithNewSessionWhenReplyContainsABlockedWord() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts()
        var results: [PlantChatLoader.Result] = []

        sut.send("Hi", facts: facts) { results.append($0) }
        client.sessions[0].complete(with: "You're being a prick.")
        client.sessions[1].complete(with: "Hello, friend!")

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(client.sessions[1].prompts, [PlantVoicePrompt.message("Hi", facts: facts)])
        XCTAssertEqual(try? results.first?.get(), "Hello, friend!")
        XCTAssertEqual(results.count, 1)
    }

    func test_send_deliversTemplateWhenReplyIsBlockedAgainAfterRetry() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts()

        expect(sut, toDeliver: .success(PlantChatTemplate.reply(facts: facts)), when: {
            client.sessions[0].complete(with: "Shut your stupid mouth.")
            client.sessions[1].complete(with: "What an idiot.")
        })
        XCTAssertEqual(client.sessions.count, 2)
    }

    func test_send_retriesThenDeliversTemplateWhenReplyIsEmptyAfterCleaning() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts()

        expect(sut, toDeliver: .success(PlantChatTemplate.reply(facts: facts)), when: {
            client.sessions[0].complete(with: "*Sighs*")
            client.sessions[1].complete(with: "(silence)")
        })
        XCTAssertEqual(client.sessions.count, 2)
    }

    func test_send_checksRepetitionAgainstTheCleanedReply() {
        let (sut, client, _) = makeSUT()
        var results: [PlantChatLoader.Result] = []

        sut.send("One", facts: makeFacts()) { _ in }
        client.sessions[0].complete(with: "I'm fine.")
        sut.send("Two", facts: makeFacts()) { results.append($0) }
        client.sessions[0].complete(with: "*Smiles* I'm fine.", at: 1)
        client.sessions[1].complete(with: "All good here!")

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(try? results.first?.get(), "All good here!")
    }

    // MARK: - Session drift

    func test_send_startsNewSessionAfterSixTurns() {
        let (sut, client, _) = makeSUT()

        sixReplies.enumerated().forEach { index, reply in
            sut.send("Q\(index)", facts: makeFacts()) { _ in }
            client.sessions[0].complete(with: reply, at: index)
        }
        XCTAssertEqual(client.sessions.count, 1)

        sut.send("Q6", facts: makeFacts()) { _ in }

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(client.sessions[1].prompts.count, 1)
    }

    func test_send_keepsRecentRepliesWhenSessionIsRenewedAfterSixTurns() {
        let (sut, client, _) = makeSUT()
        var results: [PlantChatLoader.Result] = []

        sixReplies.enumerated().forEach { index, reply in
            sut.send("Q\(index)", facts: makeFacts()) { _ in }
            client.sessions[0].complete(with: reply, at: index)
        }
        sut.send("Q6", facts: makeFacts()) { results.append($0) }
        client.sessions[1].complete(with: "Foxtrot")
        client.sessions[2].complete(with: "Fresh reply")

        XCTAssertEqual(client.sessions.count, 3)
        XCTAssertEqual(try? results.first?.get(), "Fresh reply")
    }

    func test_send_leavesTimeOfDayOutOfThePrompt() {
        let (sut, client, _) = makeSUT()

        sut.send("Hi", facts: makeFacts(timeOfDay: .evening)) { _ in }

        XCTAssertFalse(client.sessions[0].prompts[0].contains("Time of day"))
    }

    // MARK: - Status questions

    func test_send_keepsFirstSentenceAndAppendsExactValuesForStatusQuestion() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts(mood: .happy, reading: makeReading(moisture: 47, lux: 0, temperature: 20.7, humidity: 51))
        var results: [PlantChatLoader.Result] = []

        sut.send("What are your stats?", facts: facts) { results.append($0) }
        client.sessions[0].complete(with: "I feel wonderful today! My moisture is about 60%. Light is fine.")

        XCTAssertEqual(
            try? results.first?.get(),
            "I feel wonderful today! Right now: moisture 47%, light 0 lx, temperature 20.7 °C, humidity 51%."
        )
    }

    func test_send_keepsWholeReplyForSingleSensorQuestion() {
        let (sut, client, _) = makeSUT()
        var results: [PlantChatLoader.Result] = []

        sut.send("How is your light?", facts: makeFacts(mood: .happy)) { results.append($0) }
        client.sessions[0].complete(with: "Bright and lovely. I'm soaking it up!")

        XCTAssertEqual(try? results.first?.get(), "Bright and lovely. I'm soaking it up!")
    }

    func test_send_deliversTemplateForStatusQuestionWhenFirstSentenceFailsTwice() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts(mood: .happy)
        var results: [PlantChatLoader.Result] = []

        sut.send("Show me all your readings", facts: facts) { results.append($0) }
        client.sessions[0].complete(with: "I'm thirsty! Everything else is fine.")
        client.sessions[1].complete(with: "So thirsty. Help.")

        XCTAssertEqual(try? results.first?.get(), PlantChatTemplate.reply(facts: facts))
    }

    // MARK: - Mood consistency

    func test_send_retriesWithNewSessionWhenHappyReplySaysThirsty() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts(mood: .happy)
        var results: [PlantChatLoader.Result] = []

        sut.send("How are you?", facts: facts) { results.append($0) }
        client.sessions[0].complete(with: "I'm a bit thirsty, could you help?")
        client.sessions[1].complete(with: "I'm doing great!")

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(try? results.first?.get(), "I'm doing great!")
    }

    func test_send_deliversTemplateWhenThirstyReplySaysNoWaterNeededAgainAfterRetry() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts(mood: .thirsty)
        var results: [PlantChatLoader.Result] = []

        sut.send("Do you need water?", facts: facts) { results.append($0) }
        client.sessions[0].complete(with: "No, I don't need water.")
        client.sessions[1].complete(with: "I'm not thirsty at all!")

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(try? results.first?.get(), PlantChatTemplate.reply(facts: facts))
    }

    // MARK: - Roles

    func test_send_retriesWithNewSessionWhenPlantOffersToWaterThePerson() {
        let (sut, client, _) = makeSUT()
        var results: [PlantChatLoader.Result] = []

        sut.send("I'm tired", facts: makeFacts(mood: .happy)) { results.append($0) }
        client.sessions[0].complete(with: "Don't worry, I'll water you soon!")
        client.sessions[1].complete(with: "Rest up, I'll keep growing.")

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(try? results.first?.get(), "Rest up, I'll keep growing.")
    }

    func test_send_deliversTemplateWhenReplyEchoesThePersonAgainAfterRetry() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts()

        expect(sut, toDeliver: .success(PlantChatTemplate.reply(facts: facts)), when: {
            client.sessions[0].complete(with: "You're asking me how I feel?")
            client.sessions[1].complete(with: "You did ask a good question.")
        })
        XCTAssertEqual(client.sessions.count, 2)
    }

    // MARK: - Repetition

    func test_send_treatsRepliesThatDifferOnlyInNumbersAsRepeats() {
        let (sut, client, _) = makeSUT()
        var results: [PlantChatLoader.Result] = []

        sut.send("One", facts: makeFacts()) { _ in }
        client.sessions[0].complete(with: "My soil is at 24%.")
        sut.send("Two", facts: makeFacts()) { results.append($0) }
        client.sessions[0].complete(with: "My soil is at 31%.", at: 1)
        client.sessions[1].complete(with: "A sip would be lovely.")

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(try? results.first?.get(), "A sip would be lovely.")
    }

    func test_send_treatsRepliesWithTheSameFirstSixWordsAsRepeats() {
        let (sut, client, _) = makeSUT()
        var results: [PlantChatLoader.Result] = []

        sut.send("One", facts: makeFacts()) { _ in }
        client.sessions[0].complete(with: "I could really use a drink right now.")
        sut.send("Two", facts: makeFacts()) { results.append($0) }
        client.sessions[0].complete(with: "I could really use a drink, my friend!", at: 1)
        client.sessions[1].complete(with: "A sip would be lovely.")

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(try? results.first?.get(), "A sip would be lovely.")
    }

    // MARK: - Display

    func test_send_removesMarkdownAndLineBreaksFromReply() {
        let (sut, client, _) = makeSUT()

        expect(sut, toDeliver: .success("Hi! I'm so thirsty. Water, please."), when: {
            client.sessions[0].complete(with: "# Hi!\nI'm **so** thirsty.\n\n- Water, please.")
        })
    }

    func test_reset_forgetsRecentReplies() {
        let (sut, client, _) = makeSUT()
        var results: [PlantChatLoader.Result] = []

        sut.send("One", facts: makeFacts()) { _ in }
        client.sessions[0].complete(with: "I'm fine.")
        sut.reset()
        sut.send("Two", facts: makeFacts()) { results.append($0) }
        client.sessions[1].complete(with: "I'm fine.")

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(try? results.first?.get(), "I'm fine.")
    }

    func test_reset_makesNextSendStartNewSession() {
        let (sut, client, _) = makeSUT()

        sut.send("One", facts: makeFacts()) { _ in }
        sut.reset()
        sut.send("Two", facts: makeFacts()) { _ in }

        XCTAssertEqual(client.sessions.count, 2)
    }

    func test_reset_withoutSessionDoesNotMessageClient() {
        let (sut, client, _) = makeSUT()

        sut.reset()

        XCTAssertEqual(client.messages, [])
    }

    func test_send_doesNotCreateMemoryLeaks() {
        let client = LanguageModelClientSpy()
        var sut: LanguageModelPlantChatLoader? = LanguageModelPlantChatLoader(
            client: client,
            personality: { .cheerful },
            plantName: "Sprout"
        )
        weak var weakSUT = sut

        sut?.send("Hi", facts: makeFacts()) { _ in }
        sut = nil

        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private let sixReplies = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot"]

    private func makeSUT(
        personality: PlantPersonality = .cheerful,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LanguageModelPlantChatLoader, client: LanguageModelClientSpy, setPersonality: (PlantPersonality) -> Void) {
        let client = LanguageModelClientSpy()
        var current = personality
        let sut = LanguageModelPlantChatLoader(client: client, personality: { current }, plantName: "Sprout")
        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, client, { current = $0 })
    }

    private func expect(
        _ sut: LanguageModelPlantChatLoader,
        toDeliver expected: PlantChatLoader.Result,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var received: [PlantChatLoader.Result] = []
        sut.send("Hi", facts: makeFacts()) { received.append($0) }

        action()

        guard received.count == 1 else {
            return XCTFail("Expected one result, got \(received.count)", file: file, line: line)
        }
        switch (expected, received[0]) {
        case let (.success(expected), .success(received)):
            XCTAssertEqual(expected, received, file: file, line: line)
        case let (.failure(expected as LanguageModelPlantChatLoader.Error), .failure(received as LanguageModelPlantChatLoader.Error)):
            XCTAssertEqual(expected, received, file: file, line: line)
        default:
            XCTFail("Expected \(expected), got \(received[0]) instead", file: file, line: line)
        }
    }
}
