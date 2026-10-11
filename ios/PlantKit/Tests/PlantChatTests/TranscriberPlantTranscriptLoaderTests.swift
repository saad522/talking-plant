import XCTest
@testable import PlantChat

@MainActor
final class TranscriberPlantTranscriptLoaderTests: PlantChatXCTestCase {
    func test_init_doesNotMessageClient() {
        let sut = makeSUT()

        XCTAssertEqual(sut.client.messages, [])
        XCTAssertEqual(sut.schedule.intervals, [])
    }

    func test_authorization_isForwardedFromClient() {
        let sut = makeSUT()
        sut.client.authorization = .denied

        XCTAssertEqual(sut.loader.authorization, .denied)
    }

    func test_requestAuthorization_isForwardedAndCompletes() {
        let sut = makeSUT()
        var received: [PlantSpeechAuthorization] = []

        sut.loader.requestAuthorization { received.append($0) }
        sut.client.completeAuthorization(with: .authorized)

        XCTAssertEqual(sut.client.messages, [.requestAuthorization])
        XCTAssertEqual(received, [.authorized])
    }

    func test_prepare_isForwarded() {
        let sut = makeSUT()

        sut.loader.prepare()

        XCTAssertEqual(sut.client.messages, [.prepare])
    }

    func test_start_startsClientAndSchedulesNoSpeechAndMaximumDurationTimers() {
        let sut = makeSUT()

        sut.loader.start { _ in }

        XCTAssertEqual(sut.client.messages, [.start])
        XCTAssertEqual(sut.schedule.intervals, [6, 30])
    }

    func test_volatileText_replacesVolatileText() {
        let sut = makeSUT()
        let received = sut.start()

        sut.client.send(.volatile("hel"))
        sut.client.send(.volatile("hello"))

        XCTAssertEqual(received(), [partial("hel"), partial("hello")])
    }

    func test_finalSegments_append() {
        let sut = makeSUT()
        let received = sut.start()

        sut.client.send(.final("hello"))
        sut.client.send(.final("there "))

        XCTAssertEqual(received(), [partial("hello"), partial("hello there")])
    }

    func test_partial_carriesCommittedPlusVolatileText() {
        let sut = makeSUT()
        let received = sut.start()

        sut.client.send(.final("how are"))
        sut.client.send(.volatile("you"))
        sut.client.send(.final("you"))

        XCTAssertEqual(received(), [partial("how are"), partial("how are you")])
    }

    func test_unchangedText_isNotDeliveredAgain() {
        let sut = makeSUT()
        let received = sut.start()

        sut.client.send(.volatile("hello"))
        sut.client.send(.volatile("hello"))

        XCTAssertEqual(received(), [partial("hello")])
        XCTAssertEqual(sut.schedule.intervals, [6, 30, 1.5])
    }

    func test_silenceTimer_finishesClient() {
        let sut = makeSUT()
        _ = sut.start()

        sut.client.send(.volatile("hello"))
        sut.schedule.fire(at: 2)

        XCTAssertEqual(sut.client.messages, [.start, .finish])
        XCTAssertEqual(sut.schedule.intervals, [6, 30, 1.5])
    }

    func test_newWord_makesOlderSilenceTimerDoNothing() {
        let sut = makeSUT()
        _ = sut.start()

        sut.client.send(.volatile("hello"))
        sut.client.send(.volatile("hello there"))
        sut.schedule.fire(at: 2)

        XCTAssertEqual(sut.client.messages, [.start])

        sut.schedule.fire(at: 3)

        XCTAssertEqual(sut.client.messages, [.start, .finish])
    }

    func test_noSpeechTimeout_cancelsClientAndDeliversEmptyFinalTranscript() {
        let sut = makeSUT()
        let received = sut.start()

        sut.schedule.fire(at: 0)

        XCTAssertEqual(sut.client.messages, [.start, .cancel])
        XCTAssertEqual(received(), [final("")])
    }

    func test_noSpeechTimeout_doesNothingAfterFirstWord() {
        let sut = makeSUT()
        let received = sut.start()

        sut.client.send(.volatile("hello"))
        sut.schedule.fire(at: 0)

        XCTAssertEqual(sut.client.messages, [.start])
        XCTAssertEqual(received(), [partial("hello")])
    }

    func test_maximumDuration_finishesClient() {
        let sut = makeSUT()
        _ = sut.start()

        sut.client.send(.volatile("hello"))
        sut.schedule.fire(at: 1)

        XCTAssertEqual(sut.client.messages, [.start, .finish])
    }

    func test_timers_doNothingAfterListeningEnded() {
        let sut = makeSUT()
        let received = sut.start()

        sut.client.send(.volatile("hello"))
        sut.client.send(.finished)
        sut.schedule.fire(at: 0)
        sut.schedule.fire(at: 1)
        sut.schedule.fire(at: 2)

        XCTAssertEqual(sut.client.messages, [.start])
        XCTAssertEqual(received(), [partial("hello"), final("hello")])
    }

    func test_stop_finishesClient() {
        let sut = makeSUT()
        _ = sut.start()

        sut.loader.stop()

        XCTAssertEqual(sut.client.messages, [.start, .finish])
    }

    func test_finished_deliversTrimmedFinalTextOnce() {
        let sut = makeSUT()
        let received = sut.start()

        sut.client.send(.final("  hello "))
        sut.client.send(.volatile(" there  "))
        sut.client.send(.finished)
        sut.client.send(.finished)

        XCTAssertEqual(received(), [partial("hello"), partial("hello there"), final("hello there")])
    }

    func test_finishedWithNothingHeard_deliversEmptyFinalTranscript() {
        let sut = makeSUT()
        let received = sut.start()

        sut.client.send(.finished)

        XCTAssertEqual(received(), [final("")])
    }

    func test_failedWhilePreparing_deliversPreparingError() {
        let sut = makeSUT()
        let received = sut.start()

        sut.client.send(.failed(.preparing))

        XCTAssertEqual(received(), [.failure(.preparing)])
    }

    func test_failedTranscription_deliversTranscriptionErrorOnce() {
        let sut = makeSUT()
        let received = sut.start()

        sut.client.send(.failed(.transcription))
        sut.client.send(.finished)

        XCTAssertEqual(received(), [.failure(.transcription)])
    }

    func test_cancel_cancelsClientAndDeliversNothingMore() {
        let sut = makeSUT()
        let received = sut.start()

        sut.client.send(.volatile("hello"))
        sut.loader.cancel()
        sut.client.send(.volatile("hello there"))
        sut.client.send(.final("hello there"))
        sut.client.send(.finished)
        sut.schedule.fire(at: 0)
        sut.schedule.fire(at: 1)
        sut.schedule.fire(at: 2)

        XCTAssertEqual(sut.client.messages, [.start, .cancel])
        XCTAssertEqual(received(), [partial("hello")])
    }

    func test_startAgain_ignoresEventsAndTimersOfEarlierListening() {
        let sut = makeSUT()
        let first = sut.start()
        sut.client.send(.volatile("old"))
        sut.loader.cancel()

        let second = sut.start()
        sut.client.send(.volatile("stale"), at: 0)
        sut.schedule.fire(at: 0)
        sut.client.send(.volatile("new"), at: 1)

        XCTAssertEqual(first(), [partial("old")])
        XCTAssertEqual(second(), [partial("new")])
        XCTAssertEqual(sut.client.messages, [.start, .cancel, .start])
    }

    func test_start_doesNotCreateMemoryLeaks() {
        let client = TranscriberClientSpy()
        let schedule = ScheduleSpy()
        var sut: TranscriberPlantTranscriptLoader? = TranscriberPlantTranscriptLoader(
            client: client,
            schedule: schedule.schedule
        )
        weak var weakSUT = sut

        sut?.start { _ in }
        client.send(.volatile("hello"))
        sut = nil

        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SUT {
        let client = TranscriberClientSpy()
        let schedule = ScheduleSpy()
        let loader = TranscriberPlantTranscriptLoader(client: client, schedule: schedule.schedule)
        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(schedule, file: file, line: line)
        trackMemoryLeak(loader, file: file, line: line)
        return SUT(loader: loader, client: client, schedule: schedule)
    }

    @MainActor
    private struct SUT {
        let loader: TranscriberPlantTranscriptLoader
        let client: TranscriberClientSpy
        let schedule: ScheduleSpy

        /// Starts listening and returns what has been delivered so far.
        func start() -> () -> [Delivery] {
            let box = Box()
            loader.start { result in
                switch result {
                case .success(let transcript):
                    box.deliveries.append(transcript.isFinal ? .final(transcript.text) : .partial(transcript.text))
                case .failure(let error):
                    box.deliveries.append(.failure(error as? TranscriberPlantTranscriptLoader.Error))
                }
            }
            return { box.deliveries }
        }
    }

    private enum Delivery: Equatable {
        case partial(String)
        case final(String)
        case failure(TranscriberPlantTranscriptLoader.Error?)
    }

    private final class Box {
        var deliveries: [Delivery] = []
    }

    private func partial(_ text: String) -> Delivery { .partial(text) }

    private func final(_ text: String) -> Delivery { .final(text) }
}
