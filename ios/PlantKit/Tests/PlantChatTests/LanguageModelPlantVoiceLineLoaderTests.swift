import XCTest
@testable import PlantChat

@MainActor
final class LanguageModelPlantVoiceLineLoaderTests: PlantChatXCTestCase {
    func test_init_doesNotMessageClient() {
        let (_, client) = makeSUT()

        XCTAssertEqual(client.messages, [])
    }

    func test_load_failsAtOnceWithoutSessionWhenModelIsUnavailable() {
        let (sut, client) = makeSUT()
        client.isAvailable = false

        expect(sut, toDeliver: .failure(LanguageModelPlantVoiceLineLoader.Error.unavailable), when: {})
        XCTAssertEqual(client.messages, [])
    }

    func test_load_createsSessionWithoutHistoryUsingPersonalityInstructions() {
        let (sut, client) = makeSUT(personality: .politeButler)

        sut.load(makeRequest()) { _ in }

        XCTAssertEqual(client.messages, [.init(
            instructions: PlantVoicePrompt.instructions(personality: .politeButler, plantName: "Sprout"),
            canReadHistory: false
        )])
    }

    func test_load_createsFreshSessionForEveryLoad() {
        let (sut, client) = makeSUT()

        sut.load(makeRequest()) { _ in }
        sut.load(makeRequest()) { _ in }

        XCTAssertEqual(client.sessions.count, 2)
    }

    func test_load_usesCurrentPersonalityOnEveryLoad() {
        var personality = PlantPersonality.cheerful
        let client = LanguageModelClientSpy()
        let sut = LanguageModelPlantVoiceLineLoader(client: client, personality: { personality }, plantName: "Sprout")

        sut.load(makeRequest()) { _ in }
        personality = .dramatic
        sut.load(makeRequest()) { _ in }

        XCTAssertEqual(client.messages.map(\.instructions), [
            PlantVoicePrompt.instructions(personality: .cheerful, plantName: "Sprout"),
            PlantVoicePrompt.instructions(personality: .dramatic, plantName: "Sprout")
        ])
    }

    func test_load_promptsSessionWithLinePrompt() {
        let (sut, client) = makeSUT()
        let facts = makeFacts()

        sut.load(PlantVoiceLineRequest(facts: facts, purpose: .notification)) { _ in }

        XCTAssertEqual(client.sessions.first?.prompts, [PlantVoicePrompt.line(facts, purpose: .notification)])
    }

    func test_load_deliversCleanedLine() {
        let (sut, client) = makeSUT()

        expect(sut, toDeliver: .success("Water me, please!"), when: {
            client.sessions[0].complete(with: "  \"Water me, please!\"\nMore text")
        })
    }

    func test_load_deliversInvalidLineWhenCleanupRejectsText() {
        ["", "I am at 24%", String(repeating: "a", count: 101)].forEach { text in
            let (sut, client) = makeSUT()

            expect(sut, toDeliver: .failure(LanguageModelPlantVoiceLineLoader.Error.invalidLine), when: {
                client.sessions[0].complete(with: text)
            })
        }
    }

    func test_load_replacesGreetingThatDoesNotMentionTheNeedWithMoodTemplate() {
        let facts = makeFacts(mood: .thirsty)

        expect(sut: makeSUT(), loading: PlantVoiceLineRequest(facts: facts, purpose: .greeting), from: "Hello, lovely evening!",
               toDeliver: PlantChatTemplate.speech(mood: .thirsty, isSleeping: false))
    }

    func test_load_replacesGreetingThatContradictsTheMoodWithMoodTemplate() {
        let facts = makeFacts(mood: .happy)

        expect(sut: makeSUT(), loading: PlantVoiceLineRequest(facts: facts, purpose: .greeting), from: "Hi! I'm so thirsty today.",
               toDeliver: PlantChatTemplate.speech(mood: .happy, isSleeping: false))
    }

    func test_load_keepsGreetingThatFitsTheMood() {
        let facts = makeFacts(mood: .thirsty)

        expect(sut: makeSUT(), loading: PlantVoiceLineRequest(facts: facts, purpose: .greeting), from: "Hi! Could I have some water?",
               toDeliver: "Hi! Could I have some water?")
    }

    func test_load_doesNotCheckHomeAndNotificationLinesAgainstTheMood() {
        [PlantVoiceLineRequest.Purpose.home, .notification].forEach { purpose in
            expect(sut: makeSUT(), loading: PlantVoiceLineRequest(facts: makeFacts(mood: .thirsty), purpose: purpose), from: "Hello there!",
                   toDeliver: "Hello there!")
        }
    }

    func test_load_deliversGenerationErrorOnSessionFailure() {
        ([anyNSError(), PlantLanguageModelError.contextTooLong, PlantLanguageModelError.generation] as [Error]).forEach { error in
            let (sut, client) = makeSUT()

            expect(sut, toDeliver: .failure(LanguageModelPlantVoiceLineLoader.Error.generation), when: {
                client.sessions[0].complete(with: error)
            })
        }
    }

    func test_load_doesNotCreateMemoryLeaks() {
        let client = LanguageModelClientSpy()
        var sut: LanguageModelPlantVoiceLineLoader? = LanguageModelPlantVoiceLineLoader(
            client: client,
            personality: { .cheerful },
            plantName: "Sprout"
        )
        weak var weakSUT = sut

        sut?.load(makeRequest()) { _ in }
        sut = nil

        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(
        personality: PlantPersonality = .cheerful,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LanguageModelPlantVoiceLineLoader, client: LanguageModelClientSpy) {
        let client = LanguageModelClientSpy()
        let sut = LanguageModelPlantVoiceLineLoader(client: client, personality: { personality }, plantName: "Sprout")
        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, client)
    }

    private func makeRequest() -> PlantVoiceLineRequest {
        PlantVoiceLineRequest(facts: makeFacts(), purpose: .home)
    }

    private func expect(
        sut: (sut: LanguageModelPlantVoiceLineLoader, client: LanguageModelClientSpy),
        loading request: PlantVoiceLineRequest,
        from text: String,
        toDeliver expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var received: [PlantVoiceLineLoader.Result] = []
        sut.sut.load(request) { received.append($0) }

        sut.client.sessions[0].complete(with: text)

        XCTAssertEqual(received.count, 1, file: file, line: line)
        XCTAssertEqual(try? received.first?.get(), expected, file: file, line: line)
    }

    private func expect(
        _ sut: LanguageModelPlantVoiceLineLoader,
        toDeliver expected: PlantVoiceLineLoader.Result,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var received: [PlantVoiceLineLoader.Result] = []
        sut.load(makeRequest()) { received.append($0) }

        action()

        guard received.count == 1 else {
            return XCTFail("Expected one result, got \(received.count)", file: file, line: line)
        }
        switch (expected, received[0]) {
        case let (.success(expected), .success(received)):
            XCTAssertEqual(expected, received, file: file, line: line)
        case let (.failure(expected as LanguageModelPlantVoiceLineLoader.Error), .failure(received as LanguageModelPlantVoiceLineLoader.Error)):
            XCTAssertEqual(expected, received, file: file, line: line)
        default:
            XCTFail("Expected \(expected), got \(received[0]) instead", file: file, line: line)
        }
    }
}
