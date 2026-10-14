import XCTest
@testable import PlantChat

final class FallbackPlantSynthesizerClientTests: PlantChatXCTestCase {
    func test_init_sendsNothingToEitherClient() {
        let (_, primary, fallback, schedule) = makeSUT()

        XCTAssertTrue(primary.speeches.isEmpty)
        XCTAssertEqual(primary.stopCount, 0)
        XCTAssertTrue(fallback.speeches.isEmpty)
        XCTAssertEqual(fallback.stopCount, 0)
        XCTAssertTrue(schedule.intervals.isEmpty)
    }

    func test_speak_forwardsTextAndStyleToPrimaryAndSchedulesStartTimeout() {
        let (sut, primary, fallback, schedule) = makeSUT()

        sut.speak("hello", style: style) {}

        XCTAssertEqual(primary.speeches, [.init(text: "hello", style: style)])
        XCTAssertTrue(fallback.speeches.isEmpty)
        XCTAssertEqual(schedule.intervals, [FallbackPlantSynthesizerClient.startTimeout])
    }

    func test_startedThenFinished_completesOnceWithoutFallback() {
        let (sut, primary, fallback, _) = makeSUT()
        var completions = 0
        sut.speak("hello", style: style) { completions += 1 }

        primary.send(.started)
        XCTAssertEqual(completions, 0)
        primary.send(.finished)
        primary.send(.finished)

        XCTAssertEqual(completions, 1)
        XCTAssertTrue(fallback.speeches.isEmpty)
    }

    func test_failedBeforeStarted_speaksSameTextAndStyleWithFallbackAndCompletesOnce() {
        let (sut, primary, fallback, _) = makeSUT()
        var completions = 0
        sut.speak("hello", style: style) { completions += 1 }

        primary.send(.failed)

        XCTAssertEqual(fallback.speeches, [.init(text: "hello", style: style)])
        XCTAssertEqual(completions, 0)
        fallback.finish()
        fallback.finish()
        XCTAssertEqual(completions, 1)
    }

    func test_failedAfterStarted_completesOnceWithoutFallback() {
        let (sut, primary, fallback, _) = makeSUT()
        var completions = 0
        sut.speak("hello", style: style) { completions += 1 }

        primary.send(.started)
        primary.send(.failed)

        XCTAssertEqual(completions, 1)
        XCTAssertTrue(fallback.speeches.isEmpty)
    }

    func test_startTimeoutWithoutStarted_stopsPrimaryAndUsesFallback() {
        let (sut, primary, fallback, schedule) = makeSUT()
        var completions = 0
        sut.speak("hello", style: style) { completions += 1 }

        schedule.fire(at: 0)

        XCTAssertEqual(primary.stopCount, 1)
        XCTAssertEqual(fallback.speeches, [.init(text: "hello", style: style)])
        fallback.finish()
        XCTAssertEqual(completions, 1)
    }

    func test_startTimeoutAfterStarted_doesNothing() {
        let (sut, primary, fallback, schedule) = makeSUT()
        sut.speak("hello", style: style) {}
        primary.send(.started)

        schedule.fire(at: 0)

        XCTAssertEqual(primary.stopCount, 0)
        XCTAssertTrue(fallback.speeches.isEmpty)
    }

    func test_primaryEventsAfterStartTimeoutFallback_areDropped() {
        let (sut, primary, fallback, schedule) = makeSUT()
        var completions = 0
        sut.speak("hello", style: style) { completions += 1 }
        schedule.fire(at: 0)

        primary.send(.started)
        primary.send(.finished)
        primary.send(.failed)

        XCTAssertEqual(completions, 0)
        XCTAssertEqual(fallback.speeches.count, 1)
        XCTAssertEqual(fallback.stopCount, 0)
        fallback.finish()
        XCTAssertEqual(completions, 1)
    }

    func test_stopDuringPrimary_stopsPrimaryCompletesSynchronouslyOnceAndIgnoresLaterEvents() {
        let (sut, primary, fallback, _) = makeSUT()
        var completions = 0
        sut.speak("hello", style: style) { completions += 1 }

        sut.stop()

        XCTAssertEqual(primary.stopCount, 1)
        XCTAssertEqual(completions, 1)
        primary.send(.failed)
        primary.send(.finished)
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(fallback.speeches.isEmpty)
    }

    func test_stopDuringFallback_stopsFallbackAndCompletesOnceEvenWhenFallbackCompletes() {
        let (sut, primary, fallback, _) = makeSUT()
        var completions = 0
        sut.speak("hello", style: style) { completions += 1 }
        primary.send(.failed)

        sut.stop()
        fallback.finish()

        XCTAssertEqual(fallback.stopCount, 1)
        XCTAssertEqual(completions, 1)
    }

    func test_speakWhileSpeaking_completesFirstOnceThenStartsSecondIgnoringFirstEvents() {
        let (sut, primary, fallback, schedule) = makeSUT()
        var first = 0
        var second = 0
        sut.speak("one", style: style) { first += 1 }

        sut.speak("two", style: style) { second += 1 }

        XCTAssertEqual(first, 1)
        XCTAssertEqual(primary.stopCount, 1)
        XCTAssertEqual(primary.speeches.map(\.text), ["one", "two"])

        primary.send(.failed, at: 0)
        schedule.fire(at: 0)
        XCTAssertTrue(fallback.speeches.isEmpty)
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 0)

        primary.send(.started, at: 1)
        primary.send(.finished, at: 1)
        XCTAssertEqual(second, 1)
    }

    func test_stopWhenIdle_completesNothing() {
        let (sut, primary, fallback, _) = makeSUT()
        var completions = 0
        sut.speak("hello", style: style) { completions += 1 }
        primary.send(.finished)

        sut.stop()

        XCTAssertEqual(completions, 1)
        XCTAssertEqual(primary.stopCount, 0)
        XCTAssertEqual(fallback.stopCount, 0)
    }

    func test_speak_doesNotCreateMemoryLeaks() {
        let (sut, primary, fallback, _) = makeSUT()

        sut.speak("hello", style: style) {}
        primary.send(.failed)
        fallback.finish()
    }

    // MARK: - Helpers

    private var style: PlantSpeechStyle {
        PlantSpeechStyle(language: "en-US", rate: 0.5, speed: 1)
    }

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (FallbackPlantSynthesizerClient, PrimarySynthesizerSpy, SynthesizerSpy, ScheduleSpy) {
        let primary = PrimarySynthesizerSpy()
        let fallback = SynthesizerSpy()
        let schedule = ScheduleSpy()
        let sut = FallbackPlantSynthesizerClient(primary: primary, fallback: fallback, schedule: schedule.schedule)
        trackMemoryLeak(sut, file: file, line: line)
        trackMemoryLeak(primary, file: file, line: line)
        trackMemoryLeak(fallback, file: file, line: line)
        trackMemoryLeak(schedule, file: file, line: line)
        return (sut, primary, fallback, schedule)
    }
}
