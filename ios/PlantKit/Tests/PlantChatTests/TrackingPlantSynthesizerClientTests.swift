import XCTest
@testable import PlantChat

final class TrackingPlantSynthesizerClientTests: PlantChatXCTestCase {
    func test_init_isNotSpeakingAndSendsNothing() {
        let (sut, spy) = makeSUT()

        XCTAssertFalse(sut.isSpeaking)
        XCTAssertTrue(spy.speeches.isEmpty)
        XCTAssertEqual(spy.stopCount, 0)
    }

    func test_speak_forwardsToDecorateeAndIsSpeaking() {
        let (sut, spy) = makeSUT()

        sut.speak("hello", style: style) {}

        XCTAssertEqual(spy.speeches, [.init(text: "hello", style: style)])
        XCTAssertTrue(sut.isSpeaking)
    }

    func test_completion_clearsIsSpeakingAndCallsCallerOnce() {
        let (sut, spy) = makeSUT()
        var completions = 0
        sut.speak("hello", style: style) { completions += 1 }

        spy.finish()

        XCTAssertFalse(sut.isSpeaking)
        XCTAssertEqual(completions, 1)
    }

    func test_stop_forwardsAndClearsIsSpeaking() {
        let (sut, spy) = makeSUT()
        sut.speak("hello", style: style) {}

        sut.stop()

        XCTAssertEqual(spy.stopCount, 1)
        XCTAssertFalse(sut.isSpeaking)
    }

    func test_secondSpeak_staysSpeakingUntilItsOwnCompletion() {
        let (sut, spy) = makeSUT()
        sut.speak("one", style: style) {}
        sut.speak("two", style: style) {}

        spy.finish(at: 0)
        XCTAssertTrue(sut.isSpeaking)

        spy.finish(at: 1)
        XCTAssertFalse(sut.isSpeaking)
    }

    func test_oldCompletionAfterStop_doesNotClearANewSpeech() {
        let (sut, spy) = makeSUT()
        sut.speak("one", style: style) {}
        sut.stop()
        sut.speak("two", style: style) {}

        spy.finish(at: 0)

        XCTAssertTrue(sut.isSpeaking)
    }

    // MARK: - Helpers

    private var style: PlantSpeechStyle {
        PlantSpeechStyle(language: "en-US", rate: 0.5, speed: 1)
    }

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (TrackingPlantSynthesizerClient, SynthesizerSpy) {
        let spy = SynthesizerSpy()
        let sut = TrackingPlantSynthesizerClient(decoratee: spy)
        trackMemoryLeak(sut, file: file, line: line)
        trackMemoryLeak(spy, file: file, line: line)
        return (sut, spy)
    }
}
