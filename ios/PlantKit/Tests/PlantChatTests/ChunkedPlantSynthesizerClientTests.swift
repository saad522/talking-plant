import XCTest
@testable import PlantChat

final class ChunkedPlantSynthesizerClientTests: PlantChatXCTestCase {
    private let style = PlantSpeechStyle(language: "en-US", rate: 0.5, speed: 1.1)
    private let first = "This is the first sentence here."
    private let second = "And this is the second sentence."
    private let third = "Then comes the third sentence now."
    private var text: String { "\(first) \(second) \(third)" }

    func test_init_doesNothing() {
        let (_, generator, player) = makeSUT()

        XCTAssertTrue(generator.requests.isEmpty)
        XCTAssertTrue(player.messages.isEmpty)
    }

    func test_speak_startsPlayerAndAsksForFirstChunkWithStyleSpeed() async {
        let (sut, generator, player) = makeSUT()

        sut.speak(text, style: style) { _ in }
        await settle()

        XCTAssertEqual(player.messages, [.start])
        XCTAssertEqual(generator.requests, [.init(text: first, speed: 1.1)])
    }

    func test_speak_whileGeneratorIsLoading_sendsNothingUntilItCompletes() async {
        let (sut, generator, player) = makeSUT()
        var events = [PlantSpeechEvent]()

        sut.speak(text, style: style) { events.append($0) }
        await settle()
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(player.messages, [.start])

        generator.complete(with: [0.1])
        await settle()

        XCTAssertEqual(events, [.started])
        XCTAssertEqual(player.messages, [.start, .enqueue([0.1])])
    }

    func test_speak_playerStartThrows_sendsFailedAndGeneratesNothing() async {
        let (sut, generator, player) = makeSUT()
        player.startError = anyNSError()
        var events = [PlantSpeechEvent]()

        sut.speak(text, style: style) { events.append($0) }
        await settle()

        XCTAssertEqual(events, [.failed])
        XCTAssertTrue(generator.requests.isEmpty)
    }

    func test_speak_firstChunkThrows_sendsFailedWithoutStarted() async {
        let (sut, generator, player) = makeSUT()
        var events = [PlantSpeechEvent]()

        sut.speak(text, style: style) { events.append($0) }
        await settle()
        generator.complete(with: anyNSError())
        await settle()

        XCTAssertEqual(events, [.failed])
        XCTAssertEqual(player.messages, [.start, .stop])
    }

    func test_speak_firstChunkEmptyOrTooLoud_sendsFailedAndEnqueuesNothing() async {
        for samples: [Float] in [[], [0.1, 1.6], [-1.6]] {
            let (sut, generator, player) = makeSUT()
            var events = [PlantSpeechEvent]()

            sut.speak(text, style: style) { events.append($0) }
            await settle()
            generator.complete(with: samples)
            await settle()

            XCTAssertEqual(events, [.failed])
            XCTAssertEqual(player.messages, [.start, .stop])
        }
    }

    func test_speak_firstChunkOk_enqueuesStartsOnceAndRequestsOnlyNextChunk() async {
        let (sut, generator, player) = makeSUT()
        var events = [PlantSpeechEvent]()

        sut.speak(text, style: style) { events.append($0) }
        await settle()
        generator.complete(with: [0.1, -1.5])
        await settle()

        XCTAssertEqual(events, [.started])
        XCTAssertEqual(player.messages, [.start, .enqueue([0.1, -1.5])])
        XCTAssertEqual(generator.requests.map(\.text), [first, second])

        generator.complete(with: [0.2], at: 1)
        await settle()

        XCTAssertEqual(events, [.started])
        XCTAssertEqual(generator.requests.map(\.text), [first, second])

        player.complete(with: true, at: 0)
        await settle()

        XCTAssertEqual(generator.requests.map(\.text), [first, second, third])
    }

    func test_speak_generationFasterThanPlayback_neverHasMoreThanOneChunkWaiting() async {
        let (sut, generator, player) = makeSUT()
        let chunks = (0..<6).map { "Chunk number \($0) is long enough." }
        var played = 0

        sut.speak(chunks.joined(separator: " "), style: style) { _ in }
        while played < chunks.count {
            await settle()
            // The generator answers at once, the player is slower.
            while generator.requests.count > player.enqueuedCount {
                generator.complete(with: [0.1], at: player.enqueuedCount)
                await settle()
                XCTAssertLessThanOrEqual(player.enqueuedCount - played, 2)
            }
            XCTAssertLessThanOrEqual(generator.requests.count - played, 2)
            player.complete(with: true, at: played)
            played += 1
        }

        XCTAssertEqual(generator.requests.map(\.text), chunks)
    }

    func test_speak_allChunksPlayed_sendsFinishedOnce() async {
        let (sut, generator, player) = makeSUT()
        var events = [PlantSpeechEvent]()

        sut.speak(text, style: style) { events.append($0) }
        await settle()
        generator.complete(with: [0.1], at: 0)
        await settle()
        generator.complete(with: [0.1], at: 1)
        await settle()
        player.complete(with: true, at: 0)
        await settle()
        generator.complete(with: [0.1], at: 2)
        await settle()
        player.complete(with: true, at: 1)
        XCTAssertEqual(events, [.started])
        player.complete(with: true, at: 2)

        XCTAssertEqual(events, [.started, .finished])
        XCTAssertFalse(player.messages.contains(.stop))
    }

    func test_speak_laterChunkThrowsOrIsTooLoud_stopsPlayerAndSendsFailedWithoutFinished() async {
        for failure in [Result<[Float], Error>.failure(anyNSError()), .success([2]), .success([])] {
            let (sut, generator, player) = makeSUT()
            var events = [PlantSpeechEvent]()

            sut.speak(text, style: style) { events.append($0) }
            await settle()
            generator.complete(with: [0.1])
            await settle()
            switch failure {
            case let .success(samples): generator.complete(with: samples, at: 1)
            case let .failure(error): generator.complete(with: error, at: 1)
            }
            await settle()
            player.complete(with: true, at: 0)

            XCTAssertEqual(events, [.started, .failed])
            XCTAssertEqual(player.messages.last, .stop)
        }
    }

    func test_speak_completionFalse_stopsPlayerAndSendsFailed() async {
        let (sut, generator, player) = makeSUT()
        var events = [PlantSpeechEvent]()

        sut.speak(text, style: style) { events.append($0) }
        await settle()
        generator.complete(with: [0.1])
        await settle()
        player.complete(with: false)

        XCTAssertEqual(events, [.started, .failed])
        XCTAssertEqual(player.messages.last, .stop)
    }

    func test_stop_stopsPlayerAndIgnoresLateResultsAndCompletions() async {
        let (sut, generator, player) = makeSUT()
        var events = [PlantSpeechEvent]()

        sut.speak(text, style: style) { events.append($0) }
        await settle()
        generator.complete(with: [0.1])
        await settle()
        sut.stop()
        generator.complete(with: [0.2], at: 1)
        await settle()
        player.complete(with: false, at: 0)

        XCTAssertEqual(events, [.started])
        XCTAssertEqual(player.messages, [.start, .enqueue([0.1]), .stop])
        XCTAssertEqual(generator.requests.count, 2)
    }

    func test_stop_whileIdle_doesNotTouchPlayer() {
        let (sut, _, player) = makeSUT()

        sut.stop()

        XCTAssertTrue(player.messages.isEmpty)
    }

    func test_speak_whileSpeaking_firstSendsNothingMoreAndSecondRunsNormally() async {
        let (sut, generator, player) = makeSUT()
        var firstEvents = [PlantSpeechEvent]()
        var secondEvents = [PlantSpeechEvent]()

        sut.speak(text, style: style) { firstEvents.append($0) }
        await settle()
        sut.speak(first, style: style) { secondEvents.append($0) }
        await settle()
        generator.complete(with: [0.1], at: 0)
        generator.complete(with: [0.3], at: 1)
        await settle()
        player.complete(with: true, at: 0)

        XCTAssertTrue(firstEvents.isEmpty)
        XCTAssertEqual(secondEvents, [.started, .finished])
        XCTAssertEqual(player.messages, [.start, .stop, .start, .enqueue([0.3])])
    }

    func test_speak_emptyText_sendsFinishedWithoutStartingPlayer() async {
        let (sut, generator, player) = makeSUT()
        var events = [PlantSpeechEvent]()

        sut.speak("  \n ", style: style) { events.append($0) }
        await settle()

        XCTAssertEqual(events, [.finished])
        XCTAssertTrue(player.messages.isEmpty)
        XCTAssertTrue(generator.requests.isEmpty)
    }

    func test_speak_doesNotCreateMemoryLeaks() async {
        let generator = GeneratorSpy()
        let player = PlayerSpy()
        var sut: ChunkedPlantSynthesizerClient? = ChunkedPlantSynthesizerClient(generator: generator, player: player)
        trackMemoryLeak(sut!)

        sut?.speak(first, style: style) { _ in }
        await settle()
        generator.complete(with: [0.1])
        await settle()
        player.complete(with: true)
        sut = nil
    }

    // MARK: - Helpers

    private func makeSUT() -> (ChunkedPlantSynthesizerClient, GeneratorSpy, PlayerSpy) {
        let generator = GeneratorSpy()
        let player = PlayerSpy()
        let sut = ChunkedPlantSynthesizerClient(generator: generator, player: player)
        trackMemoryLeak(sut)
        return (sut, generator, player)
    }

    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }
}
