import KokoroSpike
import XCTest

final class KokoroSpikeViewModelTests: KokoroSpikeXCTestCase {
    func test_init_doesNotLoad() {
        let (_, client, _, _) = makeSUT()

        XCTAssertEqual(client.messages, [])
    }

    func test_appear_loadsOnceAndShowsLoading() {
        let (sut, client, _, _) = makeSUT()

        sut.appear()
        sut.appear()

        XCTAssertEqual(client.messages, [.load])
        XCTAssertEqual(sut.state.status, .loading)
        XCTAssertFalse(sut.state.canPlay)
    }

    func test_loadSuccess_showsReadyWithLoadTimeAndMemory() {
        let (sut, client, clock, logs) = makeSUT(memory: makeMemory(currentMB: 512, peakMB: 700))
        sut.appear()

        clock.now += 2.5
        client.completeLoad()

        XCTAssertEqual(sut.state.status, .ready)
        XCTAssertTrue(sut.state.canPlay)
        XCTAssertEqual(sut.state.metrics, ["Model load + warm-up: 2.50 s", "Memory: 512 MB now · 700 MB peak"])
        XCTAssertEqual(logs.messages.count, 1)
    }

    func test_loadMissingFiles_showsHowToFetchThem() {
        let (sut, client, _, _) = makeSUT()
        sut.appear()

        client.completeLoad(with: .failure(.missingFiles))

        XCTAssertEqual(sut.state.status, .unavailable("Model files missing. Run ios/KokoroSpike/setup.sh, then clean and rebuild."))
        XCTAssertFalse(sut.state.canPlay)
    }

    func test_loadFailure_showsReason() {
        let (sut, client, _, _) = makeSUT()
        sut.appear()

        client.completeLoad(with: .failure(.failed("bad weights")))

        XCTAssertEqual(sut.state.statusLabel, "Model failed to load: bad weights")
    }

    func test_playTap_beforeLoadDoesNothing() {
        let (sut, client, _, _) = makeSUT()
        sut.appear()

        sut.playTap()

        XCTAssertEqual(client.messages, [.load])
    }

    func test_playTap_speaksChunksOfTheLineWithSliderValues() {
        let (sut, client, _, _) = makeLoadedSUT()
        let puck = KokoroSpikeVoice.catalog.first { $0.id == "am_puck" }!
        let sky = KokoroSpikeVoice.catalog.first { $0.id == "af_sky" }!

        sut.select(.thirsty)
        sut.select(voice: sky)
        sut.select(blendVoice: puck)
        sut.setBlend(0.3)
        sut.setPitchCents(400)
        sut.setSpeed(1.1)
        sut.playTap()

        XCTAssertEqual(client.requests, [
            KokoroSpikeRequest(
                chunks: KokoroSpikeSentences.chunks(KokoroSpikeLine.thirsty.text),
                voice: sky,
                blendVoice: puck,
                blend: 0.3,
                pitchCents: 400,
                speed: 1.1
            )
        ])
        XCTAssertEqual(sut.state.status, .playing)
        XCTAssertEqual(sut.state.playLabel, "Stop")
    }

    func test_sliders_clampToTheirRanges() {
        let (sut, _, _, _) = makeSUT()

        sut.setBlend(1.5)
        sut.setPitchCents(-5_000)
        sut.setSpeed(9)

        XCTAssertEqual(sut.state.blend, 1)
        XCTAssertEqual(sut.state.pitchCents, -1200)
        XCTAssertEqual(sut.state.speed, 2)
    }

    func test_playEvents_showTimeToFirstAudioAndGeneration() {
        let (sut, client, clock, _) = makeLoadedSUT(memory: makeMemory(currentMB: 600, peakMB: 900))
        clock.now = 10
        sut.playTap()

        clock.now = 10.4
        client.send(.audioStarted)
        clock.now = 11.25
        client.send(.generated(audioSeconds: 4.25))

        XCTAssertEqual(sut.state.metrics, [
            "Model load + warm-up: 0.00 s",
            "First audio: 0.40 s",
            "Generation: 1.25 s for 4.25 s of audio (3.4× real time)",
            "Memory: 600 MB now · 900 MB peak"
        ])
        XCTAssertEqual(sut.state.status, .playing)
    }

    func test_finished_recordsTheRunAndIsReadyAgain() {
        let (sut, client, clock, logs) = makeLoadedSUT()
        sut.setPitchCents(300)
        clock.now = 10
        sut.playTap()
        clock.now = 10.5
        client.send(.audioStarted)
        clock.now = 11
        client.send(.generated(audioSeconds: 3))

        client.send(.finished)

        XCTAssertEqual(sut.state.status, .ready)
        XCTAssertEqual(sut.state.playLabel, "Play")
        XCTAssertEqual(sut.state.runs, [
            "#1 Happy · af_heart · +300 ct · ×1.00: First audio: 0.50 s · Generation: 1.00 s for 3.00 s of audio (3.0× real time)"
        ])
        XCTAssertEqual(logs.messages.last, "[KokoroSpike] " + sut.state.runs[0])
    }

    func test_runs_nameTheBlendAndKeepTheNewestFirst() {
        let (sut, client, _, _) = makeLoadedSUT()
        sut.playTap()
        client.send(.finished, at: 0)
        sut.setBlend(0.25)

        sut.playTap()
        client.send(.finished, at: 1)

        XCTAssertEqual(sut.state.runs.map { String($0.prefix(while: { $0 != ":" })) }, [
            "#2 Happy · af_heart + 25% am_puck · +0 ct · ×1.00",
            "#1 Happy · af_heart · +0 ct · ×1.00"
        ])
    }

    func test_runs_keepAtMostEight() {
        let (sut, client, _, _) = makeLoadedSUT()

        for index in 0..<10 {
            sut.playTap()
            client.send(.finished, at: index)
        }

        XCTAssertEqual(sut.state.runs.count, KokoroSpikeViewModel.maxRuns)
        XCTAssertTrue(sut.state.runs[0].hasPrefix("#10 "))
    }

    func test_failed_showsNoticeAndIsReadyAgain() {
        let (sut, client, _, _) = makeLoadedSUT()
        sut.playTap()

        client.send(.failed("audio engine: busy"))

        XCTAssertEqual(sut.state.notice, "Failed: audio engine: busy")
        XCTAssertEqual(sut.state.status, .ready)
        XCTAssertEqual(sut.state.runs, [])
    }

    func test_playTap_whilePlayingStops() {
        let (sut, client, _, _) = makeLoadedSUT()
        sut.playTap()

        sut.playTap()

        XCTAssertEqual(client.messages.last, .stop)
        XCTAssertEqual(sut.state.status, .ready)
    }

    func test_staleEventsAfterStop_areIgnored() {
        let (sut, client, _, _) = makeLoadedSUT()
        sut.playTap()
        sut.playTap()

        client.send(.audioStarted)
        client.send(.finished)

        XCTAssertEqual(sut.state.runs, [])
        XCTAssertFalse(sut.state.metrics.contains { $0.hasPrefix("First audio") })
    }

    func test_disappear_whilePlayingStops() {
        let (sut, client, _, _) = makeLoadedSUT()
        sut.playTap()

        sut.disappear()

        XCTAssertEqual(client.messages.last, .stop)
        XCTAssertEqual(sut.state.status, .ready)
    }

    func test_disappear_whenIdleDoesNothing() {
        let (sut, client, _, _) = makeLoadedSUT()

        sut.disappear()

        XCTAssertEqual(client.messages, [.load])
    }

    func test_onChange_receivesEveryChange() {
        let (sut, _, _, _) = makeSUT()
        var received: [KokoroSpikeViewModel.State] = []
        sut.onChange = { received.append($0) }

        sut.select(.sleepy)
        sut.select(.sleepy)

        XCTAssertEqual(received.map(\.line), [.sleepy])
    }

    func test_playTap_doesNotCreateMemoryLeaks() {
        let (sut, client, _, _) = makeLoadedSUT()

        sut.playTap()
        client.send(.audioStarted)
    }

    // MARK: - Helpers

    private final class LogSpy {
        var messages: [String] = []
    }

    private func makeSUT(
        memory: KokoroSpikeMemory? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (KokoroSpikeViewModel, ClientSpy, ClockStub, LogSpy) {
        let client = ClientSpy()
        let clock = ClockStub()
        let logs = LogSpy()
        let sut = KokoroSpikeViewModel(
            client: client,
            now: { [clock] in clock.now },
            memory: { memory },
            log: { [logs] in logs.messages.append($0) }
        )
        trackMemoryLeak(sut, file: file, line: line)
        trackMemoryLeak(client, file: file, line: line)
        return (sut, client, clock, logs)
    }

    private func makeLoadedSUT(
        memory: KokoroSpikeMemory? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (KokoroSpikeViewModel, ClientSpy, ClockStub, LogSpy) {
        let (sut, client, clock, logs) = makeSUT(memory: memory, file: file, line: line)
        sut.appear()
        client.completeLoad()
        return (sut, client, clock, logs)
    }
}
