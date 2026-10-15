#if DEBUG
import PlantShared
import XCTest
@testable import PlantChat

final class PlantVoiceCheckViewModelTests: PlantChatXCTestCase {
    func test_init_doesNothing() {
        let (_, client) = makeSUT()

        XCTAssertTrue(client.messages.isEmpty)
    }

    func test_text_rendersGateStateAndTimings() {
        let (sut, _) = makeSUT(snapshot: makeSnapshot(
            physicalMemory: 6_000_000_000,
            state: .loaded,
            loadSeconds: 1.234,
            warmUpSeconds: 0.5,
            memoryNowBytes: 600 * 1_048_576,
            memoryPeakBytes: 700 * 1_048_576
        ))

        XCTAssertEqual(sut.voiceIDText, "voice-1")
        XCTAssertEqual(sut.gateText, "pass: 6.0 GB of 5.5 GB needed")
        XCTAssertEqual(sut.stateText, "loaded")
        XCTAssertEqual(sut.loadText, "1.23 s")
        XCTAssertEqual(sut.warmUpText, "0.50 s")
        XCTAssertEqual(sut.memoryText, "600 MB now, 700 MB peak")
    }

    func test_text_withoutData_rendersDashes() {
        let (sut, _) = makeSUT(snapshot: makeSnapshot(physicalMemory: 4_000_000_000))

        XCTAssertEqual(sut.gateText, "fail: 4.0 GB of 5.5 GB needed")
        XCTAssertEqual(sut.stateText, "not loaded")
        XCTAssertEqual(sut.loadText, "-")
        XCTAssertEqual(sut.memoryText, "- now, - peak")
        XCTAssertEqual(sut.firstAudioText, "-")
        XCTAssertEqual(sut.chunkTexts, [])
        XCTAssertEqual(sut.watchdogText, "-")
    }

    func test_text_rendersLastUtterance() {
        var metrics = ChunkedPlantSynthesizerClient.Metrics()
        metrics.firstAudioSeconds = 0.8
        metrics.chunks = [.init(characters: 20, seconds: 0.4), .init(characters: 31, seconds: 0.9)]
        metrics.watchdogFired = true
        let (sut, _) = makeSUT(snapshot: makeSnapshot(utterance: metrics))

        XCTAssertEqual(sut.firstAudioText, "0.80 s")
        XCTAssertEqual(sut.chunkTexts, ["1: 20 chars, 0.40 s", "2: 31 chars, 0.90 s"])
        XCTAssertEqual(sut.watchdogText, "yes")
    }

    func test_resetPeak_resetsTheClientAndReadsTheSnapshotAgain() {
        let (sut, client) = makeSUT(snapshot: makeSnapshot(memoryPeakBytes: 900 * 1_048_576))

        client.snapshot = makeSnapshot(memoryPeakBytes: 500 * 1_048_576)
        sut.resetPeak()

        XCTAssertEqual(client.messages, [.resetPeak])
        XCTAssertEqual(sut.memoryText, "- now, 500 MB peak")
    }

    func test_refresh_readsTheClientSnapshotAgain() {
        let (sut, client) = makeSUT()

        client.snapshot = makeSnapshot(state: .loading)
        sut.refresh()

        XCTAssertEqual(sut.stateText, "loading")
    }

    func test_load_loadsAndKeepsTheFailure() async {
        let (sut, client) = makeSUT()
        client.loadError = "missing resources"

        await sut.load()

        XCTAssertEqual(client.messages, [.load])
        XCTAssertEqual(sut.loadError, "missing resources")
        XCTAssertFalse(sut.isLoading)
    }

    func test_unload_unloadsTheClient() {
        let (sut, client) = makeSUT()

        sut.unload()

        XCTAssertEqual(client.messages, [.unload])
    }

    func test_speakSample_speaksTheSameSentenceWithTheMoodSpeed() {
        let (sut, client) = makeSUT()

        sut.speakSample(mood: .happy)
        sut.speakSample(mood: .drowning)

        XCTAssertEqual(client.spoken.map(\.text), [PlantVoiceCheckViewModel.sampleSentence, PlantVoiceCheckViewModel.sampleSentence])
        XCTAssertEqual(client.spoken.map(\.appleOnly), [false, false])
        XCTAssertEqual(client.spoken[0].style, PlantPersonality.cheerful.speechStyle.adjusted(for: .happy))
        XCTAssertEqual(client.spoken[1].style, PlantPersonality.cheerful.speechStyle.adjusted(for: .drowning))
        XCTAssertLessThan(client.spoken[1].style.speed, client.spoken[0].style.speed)
    }

    func test_speakWithAppleVoice_speaksThroughTheFallbackOnly() {
        let (sut, client) = makeSUT()

        sut.speakWithAppleVoice()

        XCTAssertEqual(client.spoken.map(\.appleOnly), [true])
    }

    func test_speak_isMarkedUntilCompletionAndStopClearsIt() {
        let (sut, client) = makeSUT()

        sut.speakSample(mood: .thirsty)
        XCTAssertEqual(sut.speaking, "thirsty")

        client.spoken[0].completion()
        XCTAssertNil(sut.speaking)

        sut.speakSample(mood: .tooHot)
        sut.stop()
        XCTAssertNil(sut.speaking)
        XCTAssertEqual(client.messages.last, .stop)
    }

    func test_speakCompletion_refreshesSnapshot() {
        let (sut, client) = makeSUT()

        sut.speakSample(mood: .happy)
        client.snapshot = makeSnapshot(state: .loaded)
        client.spoken[0].completion()

        XCTAssertEqual(sut.stateText, "loaded")
    }

    // MARK: - Helpers

    private func makeSUT(snapshot: PlantVoiceCheckSnapshot? = nil) -> (PlantVoiceCheckViewModel, ClientSpy) {
        let client = ClientSpy(snapshot: snapshot ?? makeSnapshot())
        let sut = PlantVoiceCheckViewModel(client: client)
        trackMemoryLeak(sut)
        trackMemoryLeak(client)
        return (sut, client)
    }

    private func makeSnapshot(
        physicalMemory: UInt64 = 6_000_000_000,
        state: PlantVoiceCheckSnapshot.State = .notLoaded,
        loadSeconds: Double? = nil,
        warmUpSeconds: Double? = nil,
        memoryNowBytes: UInt64? = nil,
        memoryPeakBytes: UInt64? = nil,
        utterance: ChunkedPlantSynthesizerClient.Metrics? = nil
    ) -> PlantVoiceCheckSnapshot {
        PlantVoiceCheckSnapshot(
            voiceID: "voice-1",
            physicalMemory: physicalMemory,
            minimumPhysicalMemory: 5_500_000_000,
            state: state,
            loadSeconds: loadSeconds,
            warmUpSeconds: warmUpSeconds,
            memoryNowBytes: memoryNowBytes,
            memoryPeakBytes: memoryPeakBytes,
            utterance: utterance
        )
    }

    private final class ClientSpy: PlantVoiceCheckClient {
        enum Message: Equatable {
            case load
            case unload
            case resetPeak
            case stop
        }

        struct Spoken {
            let text: String
            let style: PlantSpeechStyle
            let appleOnly: Bool
            let completion: () -> Void
        }

        var snapshot: PlantVoiceCheckSnapshot
        var loadError: String?
        private(set) var messages = [Message]()
        private(set) var spoken = [Spoken]()

        init(snapshot: PlantVoiceCheckSnapshot) {
            self.snapshot = snapshot
        }

        func load() async -> String? {
            messages.append(.load)
            return loadError
        }

        func unload() { messages.append(.unload) }
        func resetPeak() { messages.append(.resetPeak) }
        func stop() { messages.append(.stop) }

        func speak(_ text: String, style: PlantSpeechStyle, appleOnly: Bool, completion: @escaping () -> Void) {
            spoken.append(Spoken(text: text, style: style, appleOnly: appleOnly, completion: completion))
        }
    }
}
#endif
