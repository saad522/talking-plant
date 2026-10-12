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

        (0..<6).forEach { index in
            sut.send("Q\(index)", facts: makeFacts()) { _ in }
            client.sessions[0].complete(with: "Reply \(index)", at: index)
        }
        XCTAssertEqual(client.sessions.count, 1)

        sut.send("Q6", facts: makeFacts()) { _ in }

        XCTAssertEqual(client.sessions.count, 2)
        XCTAssertEqual(client.sessions[1].prompts.count, 1)
    }

    func test_send_keepsRecentRepliesWhenSessionIsRenewedAfterSixTurns() {
        let (sut, client, _) = makeSUT()
        var results: [PlantChatLoader.Result] = []

        (0..<6).forEach { index in
            sut.send("Q\(index)", facts: makeFacts()) { _ in }
            client.sessions[0].complete(with: "Reply \(index)", at: index)
        }
        sut.send("Q6", facts: makeFacts()) { results.append($0) }
        client.sessions[1].complete(with: "Reply 5")
        client.sessions[2].complete(with: "Fresh reply")

        XCTAssertEqual(client.sessions.count, 3)
        XCTAssertEqual(try? results.first?.get(), "Fresh reply")
    }

    func test_send_includesTimeOfDayInThePrompt() {
        let (sut, client, _) = makeSUT()
        let facts = makeFacts(timeOfDay: .morning)

        sut.send("Hi", facts: facts) { _ in }

        XCTAssertTrue(client.sessions[0].prompts[0].contains("Time of day: morning."))
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
