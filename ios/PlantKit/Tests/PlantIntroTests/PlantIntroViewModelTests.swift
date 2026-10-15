import XCTest
@testable import PlantIntro

@MainActor
final class PlantIntroViewModelTests: PlantIntroXCTestCase {
    func test_init_coldLaunchShowsTheIntro() {
        let sut = makeSUT(isColdLaunch: true)

        XCTAssertTrue(sut.shouldShowIntro)
        XCTAssertTrue(sut.isVisible)
        XCTAssertEqual(sut.state, .ready)
    }

    func test_init_warmLaunchNeverShowsTheIntro() {
        let sut = makeSUT(isColdLaunch: false)

        XCTAssertFalse(sut.shouldShowIntro)
        XCTAssertFalse(sut.isVisible)
        XCTAssertEqual(sut.state, .finished)
    }

    func test_warmLaunch_ignoresEveryEvent() {
        let sut = makeSUT(isColdLaunch: false)

        sut.start()
        sut.skip()
        sut.beginHandoff()

        XCTAssertEqual(sut.state, .finished)
    }

    func test_init_deliversGreetingFromHour() {
        XCTAssertEqual(makeSUT(hour: 8).greeting, "Good morning!")
        XCTAssertEqual(makeSUT(hour: 23).greeting, "Shh... sweet dreams")
        XCTAssertEqual(makeSUT(hour: 8).particleStyle, .pollen)
        XCTAssertEqual(makeSUT(hour: 20).particleStyle, .fireflies)
    }

    func test_start_playsTheFullIntro() {
        let sut = makeSUT()

        sut.start()

        XCTAssertEqual(sut.state, .playing)
        XCTAssertTrue(sut.playsMotion)
        XCTAssertEqual(sut.handoffDelay, 1.6)
    }

    func test_beginHandoff_movesFromPlayingToHandingOffWithTheFullDuration() {
        let sut = makeSUT()
        sut.start()

        sut.beginHandoff()

        XCTAssertEqual(sut.state, .handingOff)
        XCTAssertEqual(sut.handoffDuration, 0.6)
    }

    func test_fullIntroLastsNoMoreThanTwoPointTwoSeconds() {
        let sut = makeSUT()

        XCTAssertEqual(sut.handoffDelay + sut.handoffDuration, 2.2, accuracy: 0.0001)
    }

    func test_beginHandoff_isIgnoredBeforeStart() {
        let sut = makeSUT()

        sut.beginHandoff()

        XCTAssertEqual(sut.state, .ready)
    }

    func test_skip_whilePlayingHandsOffQuickly() {
        let sut = makeSUT()
        sut.start()

        sut.skip()

        XCTAssertEqual(sut.state, .handingOff)
        XCTAssertEqual(sut.handoffDuration, 0.3)
    }

    func test_skip_beforeStartHandsOffQuickly() {
        let sut = makeSUT()

        sut.skip()

        XCTAssertEqual(sut.state, .handingOff)
        XCTAssertEqual(sut.handoffDuration, 0.3)
    }

    func test_skip_duringHandoffKeepsTheRunningHandoff() {
        let sut = makeSUT()
        sut.start()
        sut.beginHandoff()

        sut.skip()

        XCTAssertEqual(sut.state, .handingOff)
        XCTAssertEqual(sut.handoffDuration, 0.6)
    }

    func test_beginHandoff_afterSkipIsIgnored() {
        let sut = makeSUT()
        sut.start()
        sut.skip()

        sut.beginHandoff()

        XCTAssertEqual(sut.handoffDuration, 0.3)
    }

    func test_start_withReduceMotionCrossfadesWithoutMotion() {
        let sut = makeSUT(reduceMotion: true)

        sut.start()

        XCTAssertEqual(sut.state, .handingOff)
        XCTAssertFalse(sut.playsMotion)
        XCTAssertEqual(sut.handoffDuration, 0.3)
    }

    func test_complete_finishesOnlyAfterTheHandoffBegan() {
        let sut = makeSUT()

        sut.complete()
        XCTAssertEqual(sut.state, .ready)

        sut.start()
        sut.complete()
        XCTAssertEqual(sut.state, .playing)

        sut.beginHandoff()
        sut.complete()
        XCTAssertEqual(sut.state, .finished)
        XCTAssertFalse(sut.isVisible)
    }

    func test_complete_notifiesOnce() {
        let sut = makeSUT()
        var completions = 0
        sut.completed = { completions += 1 }
        sut.start()
        sut.beginHandoff()

        sut.complete()
        sut.complete()

        XCTAssertEqual(completions, 1)
    }

    func test_start_isIgnoredOnceStarted() {
        let sut = makeSUT()
        sut.start()
        sut.beginHandoff()

        sut.start()

        XCTAssertEqual(sut.state, .handingOff)
    }

    // MARK: - Helpers

    private func makeSUT(
        isColdLaunch: Bool = true,
        reduceMotion: Bool = false,
        hour: Int = 9,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> PlantIntroViewModel {
        let sut = PlantIntroViewModel(isColdLaunch: isColdLaunch, reduceMotion: reduceMotion, hour: hour)
        trackMemoryLeak(sut, file: file, line: line)
        return sut
    }
}
