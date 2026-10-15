import PlantShared
import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorSproutViewModelTests: PlantMonitorXCTestCase {
    private let thirstyLine = PlantMonitorSpokenLine(text: "Water, please!", mood: .veryThirsty, isSleeping: false)
    private let happyLine = PlantMonitorSpokenLine(text: "Feeling great!", mood: .happy, isSleeping: false)
    private let offlineLine = PlantMonitorSpokenLine(text: "Zzz… I can't feel my sensor.", mood: .offline, isSleeping: false)

    // MARK: - Automatic lines

    func test_automatic_saysNothingBeforeSettleDelay() {
        let (sut, voice, schedule, _) = makeSUT()

        sut.appear()
        sut.lineSettled(happyLine)

        XCTAssertEqual(schedule.intervals, [PlantMonitorSproutViewModel.settleDelay])
        XCTAssertEqual(voice.spoken, [])
    }

    func test_automatic_speaksAfterSettleDelayWithAutomaticTrigger() {
        let (sut, voice, schedule, _) = makeSUT()

        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()

        XCTAssertEqual(voice.spoken, [.init(text: "Feeling great!", mood: .happy, trigger: .automatic)])
    }

    func test_automatic_speaksALineThatArrivesAfterTheSettleDelay() {
        let (sut, voice, schedule, _) = makeSUT()

        sut.appear()
        schedule.fire()
        XCTAssertEqual(voice.spoken, [])
        sut.lineSettled(happyLine)

        XCTAssertEqual(voice.spoken.map(\.text), ["Feeling great!"])
    }

    func test_automatic_isSilentWhenHomeDisappearsDuringSettleDelay() {
        let (sut, voice, schedule, _) = makeSUT()

        sut.appear()
        sut.lineSettled(happyLine)
        sut.disappear()
        schedule.fire()

        XCTAssertEqual(voice.spoken, [])
    }

    func test_automatic_isSilentWhileAppIsInactive() {
        let (sut, voice, schedule, _) = makeSUT()

        sut.appear()
        sut.setActive(false)
        sut.lineSettled(happyLine)
        schedule.fire()

        XCTAssertEqual(voice.spoken, [])
    }

    func test_automatic_settlesAgainWhenAppBecomesActive() {
        let (sut, _, schedule, _) = makeSUT()
        sut.appear()

        sut.setActive(false)
        sut.setActive(true)

        XCTAssertEqual(schedule.intervals, [PlantMonitorSproutViewModel.settleDelay, PlantMonitorSproutViewModel.settleDelay])
    }

    func test_automatic_speaksAfterReturningFromBackgroundOnANewDay() {
        let (sut, voice, schedule, clock) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire(at: 0)
        voice.finish()
        sut.setActive(false)
        clock.advance(by: 12 * 3_600)

        sut.setActive(true)
        schedule.fire(at: 1)

        XCTAssertEqual(voice.spoken.count, 2)
    }

    func test_automatic_speaksWhenMoodChangesWhileVisible() {
        let (sut, voice, schedule, clock) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()
        voice.finish()
        clock.advance(by: PlantMonitorSproutViewModel.minimumGap)

        sut.lineSettled(thirstyLine)

        XCTAssertEqual(voice.spoken.map(\.text), ["Feeling great!", "Water, please!"])
    }

    func test_automatic_secondChangeWithinGapIsSpokenWhenGapEnds() {
        let (sut, voice, schedule, clock) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()
        voice.finish()
        clock.advance(by: 20)

        sut.lineSettled(thirstyLine)
        XCTAssertEqual(voice.spoken.map(\.text), ["Feeling great!"])
        XCTAssertEqual(schedule.intervals.last, PlantMonitorSproutViewModel.minimumGap - 20)

        clock.advance(by: PlantMonitorSproutViewModel.minimumGap - 20)
        schedule.fire(at: 1)

        XCTAssertEqual(voice.spoken.map(\.text), ["Feeling great!", "Water, please!"])
    }

    func test_automatic_gapEndStaysSilentWhenHomeWasLeft() {
        let (sut, voice, schedule, clock) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()
        voice.finish()
        clock.advance(by: 20)
        sut.lineSettled(thirstyLine)

        sut.disappear()
        clock.advance(by: 40)
        schedule.fire(at: 1)

        XCTAssertEqual(voice.spoken.map(\.text), ["Feeling great!"])
    }

    func test_automatic_gapEndStaysSilentWhenMoodWentBackToTheSpokenOne() {
        let (sut, voice, schedule, clock) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()
        voice.finish()
        clock.advance(by: 20)
        sut.lineSettled(thirstyLine)
        sut.lineSettled(happyLine)

        clock.advance(by: 40)
        schedule.fire(at: 1)

        XCTAssertEqual(voice.spoken.map(\.text), ["Feeling great!"])
    }

    func test_automatic_sameMoodSameDayStaysQuiet() {
        let defaults = DefaultsSpy()
        let (first, firstVoice, firstSchedule, clock) = makeSUT(defaults: defaults)
        first.appear()
        first.lineSettled(happyLine)
        firstSchedule.fire()
        XCTAssertEqual(firstVoice.spoken.count, 1)

        let (second, secondVoice, secondSchedule, _) = makeSUT(defaults: defaults, clock: clock)
        second.appear()
        second.lineSettled(happyLine)
        secondSchedule.fire()

        XCTAssertEqual(secondVoice.spoken, [])
    }

    func test_automatic_speaksAgainOnANewDay() {
        let defaults = DefaultsSpy()
        let (first, firstVoice, firstSchedule, clock) = makeSUT(defaults: defaults)
        first.appear()
        first.lineSettled(happyLine)
        firstSchedule.fire()
        XCTAssertEqual(firstVoice.spoken.count, 1)
        clock.advance(by: 24 * 3_600)

        let (second, secondVoice, secondSchedule, _) = makeSUT(defaults: defaults, clock: clock)
        second.appear()
        second.lineSettled(happyLine)
        secondSchedule.fire()

        XCTAssertEqual(secondVoice.spoken.map(\.text), ["Feeling great!"])
    }

    func test_automatic_neverSpeaksWhenDisabled() {
        let (sut, voice, schedule, _) = makeSUT(isEnabled: false)

        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()

        XCTAssertEqual(voice.spoken, [])
    }

    func test_automatic_skipsOfflineMood() {
        let (sut, voice, schedule, _) = makeSUT()

        sut.appear()
        sut.lineSettled(offlineLine)
        schedule.fire()

        XCTAssertEqual(voice.spoken, [])
    }

    func test_automatic_speaksOnceConnectedAfterOffline() {
        let (sut, voice, schedule, _) = makeSUT()
        sut.appear()
        sut.lineSettled(offlineLine)
        schedule.fire()

        sut.lineSettled(happyLine)

        XCTAssertEqual(voice.spoken.map(\.text), ["Feeling great!"])
    }

    func test_automatic_savesMoodAndDayWhenSpeaking() {
        let defaults = DefaultsSpy()
        let (sut, _, schedule, clock) = makeSUT(defaults: defaults)

        sut.appear()
        sut.lineSettled(thirstyLine)
        schedule.fire()

        let store = PlantSpokenLineStore(defaults: defaults)
        XCTAssertEqual(store.mood, .veryThirsty)
        XCTAssertEqual(store.day, PlantSpokenLineStore.day(for: clock.now(), calendar: utcCalendar()))
    }

    func test_automatic_savesNothingWhenSilent() {
        let defaults = DefaultsSpy()
        let (sut, _, schedule, _) = makeSUT(defaults: defaults, isEnabled: false)

        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()

        XCTAssertNil(PlantSpokenLineStore(defaults: defaults).mood)
    }

    // MARK: - Tap

    func test_tap_speaksCurrentLineWithTapTrigger() {
        let (sut, voice, _, _) = makeSUT()
        sut.appear()
        sut.lineSettled(thirstyLine)

        sut.sproutTap()

        XCTAssertEqual(voice.spoken, [.init(text: "Water, please!", mood: .veryThirsty, trigger: .tap)])
    }

    func test_tap_speaksOfflineLine() {
        let (sut, voice, _, _) = makeSUT()
        sut.appear()
        sut.lineSettled(offlineLine)

        sut.sproutTap()

        XCTAssertEqual(voice.spoken, [.init(text: offlineLine.text, mood: .offline, trigger: .tap)])
    }

    func test_tap_doesNothingWithoutALine() {
        let (sut, voice, _, _) = makeSUT()
        sut.appear()

        sut.sproutTap()

        XCTAssertEqual(voice.spoken, [])
    }

    func test_tap_doesNothingWhenDisabled() {
        let (sut, voice, _, _) = makeSUT(isEnabled: false)
        sut.appear()
        sut.lineSettled(happyLine)

        sut.sproutTap()

        XCTAssertEqual(voice.spoken, [])
    }

    func test_tap_whileAutomaticLinePlaysStopsItAndSpeaksAgainWithTapTrigger() {
        let (sut, voice, schedule, _) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()

        sut.sproutTap()

        XCTAssertEqual(voice.stopCount, 1)
        XCTAssertEqual(voice.spoken.map(\.trigger), [.automatic, .tap])
        XCTAssertEqual(voice.spoken.map(\.text), ["Feeling great!", "Feeling great!"])
    }

    func test_tap_whileTappedLinePlaysIsIgnored() {
        let (sut, voice, _, _) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        sut.sproutTap()

        sut.sproutTap()

        XCTAssertEqual(voice.spoken.count, 1)
        XCTAssertEqual(voice.stopCount, 0)
    }

    func test_tap_speaksAgainOnceTheTappedLineEnded() {
        let (sut, voice, _, _) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        sut.sproutTap()
        voice.finish()

        sut.sproutTap()

        XCTAssertEqual(voice.spoken.count, 2)
    }

    func test_tap_stoppedAutomaticLinesLateCompletionDoesNotClearTheTappedOne() {
        let (sut, voice, schedule, _) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()
        sut.sproutTap()

        voice.finish(at: 0)
        sut.sproutTap()

        XCTAssertEqual(voice.spoken.count, 2)
        XCTAssertEqual(voice.stopCount, 1)
    }

    func test_tap_countsAsSpokenToday() {
        let defaults = DefaultsSpy()
        let (sut, _, _, _) = makeSUT(defaults: defaults)
        sut.appear()
        sut.lineSettled(thirstyLine)

        sut.sproutTap()

        XCTAssertEqual(PlantSpokenLineStore(defaults: defaults).mood, .veryThirsty)
    }

    func test_tap_doesNotStartTheAutomaticGap() {
        let (sut, voice, schedule, _) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        sut.sproutTap()
        voice.finish()
        schedule.fire()
        sut.lineSettled(thirstyLine)

        XCTAssertEqual(voice.spoken.map(\.text), ["Feeling great!", "Water, please!"])
    }

    // MARK: - Leaving home

    func test_disappear_whileSpeakingStopsOnce() {
        let (sut, voice, schedule, _) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()

        sut.disappear()
        sut.disappear()

        XCTAssertEqual(voice.stopCount, 1)
    }

    func test_disappear_whileSilentDoesNotStop() {
        let (sut, voice, _, _) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)

        sut.disappear()

        XCTAssertEqual(voice.stopCount, 0)
    }

    func test_disappear_afterLineEndedDoesNotStop() {
        let (sut, voice, schedule, _) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()
        voice.finish()

        sut.disappear()

        XCTAssertEqual(voice.stopCount, 0)
    }

    func test_inactive_whileSpeakingStops() {
        let (sut, voice, schedule, _) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()

        sut.setActive(false)

        XCTAssertEqual(voice.stopCount, 1)
    }

    func test_disappear_whileTappedLineIsPlayingStops() {
        let (sut, voice, _, _) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        sut.sproutTap()

        sut.disappear()

        XCTAssertEqual(voice.stopCount, 1)
    }

    func test_comingBackAfterLeaving_staysSilentWithTheSameMood() {
        let (sut, voice, schedule, _) = makeSUT()
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire(at: 0)
        voice.finish()
        sut.disappear()

        sut.appear()
        schedule.fire(at: 1)

        XCTAssertEqual(voice.spoken.count, 1)
    }

    // MARK: - Shake

    func test_shake_subscribesOnceOnAppear() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, _, _, _) = makeSUT(shakeLoader: shakeLoader)

        sut.appear()
        sut.disappear()
        sut.appear()

        XCTAssertEqual(shakeLoader.subscriptionCount, 1)
    }

    func test_shake_whileVisibleIsSurprisedThenCalmAfterOneSecond() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, _, schedule, _) = makeSUT(shakeLoader: shakeLoader)
        var surprised: [Bool] = []
        sut.loadedSurprised = { surprised.append($0) }
        sut.appear()
        sut.lineSettled(happyLine)

        shakeLoader.shake()
        XCTAssertEqual(surprised, [true])
        XCTAssertEqual(schedule.intervals.suffix(2), [PlantMonitorSproutViewModel.shakeLineDelay, PlantMonitorSproutViewModel.surpriseDuration])

        schedule.fire(at: schedule.intervals.count - 1)

        XCTAssertEqual(surprised, [true, false])
    }

    func test_shake_speaksShakeLineAfterDelayWithAutomaticTrigger() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, voice, schedule, _) = makeSUT(shakeLoader: shakeLoader)
        sut.appear()
        sut.lineSettled(happyLine)

        shakeLoader.shake()
        XCTAssertEqual(voice.spoken, [])
        schedule.fire(at: schedule.intervals.count - 2)

        XCTAssertEqual(voice.spoken, [.init(text: PlantMonitorShakeLines.lines(for: .happy, isSleeping: false)[0], mood: .happy, trigger: .automatic)])
    }

    func test_shake_sleepingUsesSleepingLines() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, voice, schedule, _) = makeSUT(shakeLoader: shakeLoader)
        sut.appear()
        sut.lineSettled(.init(text: "Zzz", mood: .happy, isSleeping: true))

        shakeLoader.shake()
        schedule.fire(at: schedule.intervals.count - 2)

        XCTAssertEqual(voice.spoken.map(\.text), [PlantMonitorShakeLines.lines(for: .happy, isSleeping: true)[0]])
    }

    func test_shake_withinCooldownIsIgnoredAndAfterItAccepted() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, _, _, clock) = makeSUT(shakeLoader: shakeLoader)
        var surprised: [Bool] = []
        sut.loadedSurprised = { surprised.append($0) }
        sut.appear()
        sut.lineSettled(happyLine)

        shakeLoader.shake()
        clock.advance(by: PlantMonitorSproutViewModel.shakeCooldown - 1)
        shakeLoader.shake()
        XCTAssertEqual(surprised, [true])

        clock.advance(by: 1)
        shakeLoader.shake()
        XCTAssertEqual(surprised, [true, true])
    }

    func test_shake_whenHiddenIsIgnored() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, voice, schedule, _) = makeSUT(shakeLoader: shakeLoader)
        var surprised: [Bool] = []
        sut.loadedSurprised = { surprised.append($0) }
        sut.appear()
        sut.lineSettled(happyLine)
        sut.disappear()
        let scheduled = schedule.intervals.count

        shakeLoader.shake()

        XCTAssertEqual(surprised, [])
        XCTAssertEqual(schedule.intervals.count, scheduled)
        XCTAssertEqual(voice.spoken, [])
    }

    func test_shake_whileAppIsInactiveIsIgnored() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, _, _, _) = makeSUT(shakeLoader: shakeLoader)
        var surprised: [Bool] = []
        sut.loadedSurprised = { surprised.append($0) }
        sut.appear()
        sut.lineSettled(happyLine)
        sut.setActive(false)

        shakeLoader.shake()

        XCTAssertEqual(surprised, [])
    }

    func test_shake_beforeAMoodIsKnownIsIgnored() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, _, _, _) = makeSUT(shakeLoader: shakeLoader)
        var surprised: [Bool] = []
        sut.loadedSurprised = { surprised.append($0) }
        sut.appear()

        shakeLoader.shake()

        XCTAssertEqual(surprised, [])
    }

    func test_shake_ignoredShakeDoesNotStartTheCooldown() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, _, _, _) = makeSUT(shakeLoader: shakeLoader)
        var surprised: [Bool] = []
        sut.loadedSurprised = { surprised.append($0) }
        sut.appear()
        shakeLoader.shake()

        sut.lineSettled(happyLine)
        shakeLoader.shake()

        XCTAssertEqual(surprised, [true])
    }

    func test_shake_withSpeechDisabledIsSurprisedButSpeaksNothing() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, voice, schedule, _) = makeSUT(isEnabled: false, shakeLoader: shakeLoader)
        var surprised: [Bool] = []
        sut.loadedSurprised = { surprised.append($0) }
        sut.appear()
        sut.lineSettled(happyLine)

        shakeLoader.shake()
        schedule.fire(at: schedule.intervals.count - 2)

        XCTAssertEqual(surprised, [true])
        XCTAssertEqual(voice.spoken, [])
    }

    func test_shake_leavingHomeBeforeTheLineStaysSilentButStillCalmsTheFace() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, voice, schedule, _) = makeSUT(shakeLoader: shakeLoader)
        var surprised: [Bool] = []
        sut.loadedSurprised = { surprised.append($0) }
        sut.appear()
        sut.lineSettled(happyLine)
        shakeLoader.shake()
        let last = schedule.intervals.count

        sut.disappear()
        schedule.fire(at: last - 2)
        schedule.fire(at: last - 1)

        XCTAssertEqual(voice.spoken, [])
        XCTAssertEqual(surprised, [true, false])
    }

    func test_shake_whileAHomeLinePlaysStopsItThenSpeaksTheShakeLine() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, voice, schedule, _) = makeSUT(shakeLoader: shakeLoader)
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()

        shakeLoader.shake()
        XCTAssertEqual(voice.stopCount, 1)
        schedule.fire(at: schedule.intervals.count - 2)

        XCTAssertEqual(voice.spoken.map(\.trigger), [.automatic, .automatic])
        XCTAssertEqual(voice.spoken.last?.text, PlantMonitorShakeLines.lines(for: .happy, isSleeping: false)[0])
    }

    func test_shake_leavesTheSpokenMemoryUnchanged() {
        let defaults = DefaultsSpy()
        let shakeLoader = ShakeLoaderStub()
        let (sut, _, schedule, _) = makeSUT(defaults: defaults, shakeLoader: shakeLoader)
        sut.appear()
        sut.lineSettled(thirstyLine)

        shakeLoader.shake()
        schedule.fire(at: schedule.intervals.count - 2)

        XCTAssertNil(PlantSpokenLineStore(defaults: defaults).mood)
    }

    func test_shake_lineCanBeTappedAwayAndTheTapSpeaksTheBubbleLine() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, voice, schedule, _) = makeSUT(shakeLoader: shakeLoader)
        sut.appear()
        sut.lineSettled(happyLine)
        shakeLoader.shake()
        schedule.fire(at: schedule.intervals.count - 2)

        sut.sproutTap()

        XCTAssertEqual(voice.stopCount, 1)
        XCTAssertEqual(voice.spoken.last, .init(text: "Feeling great!", mood: .happy, trigger: .tap))
    }

    func test_shake_afterAnAutomaticLineEndedDoesNotStop() {
        let shakeLoader = ShakeLoaderStub()
        let (sut, voice, schedule, _) = makeSUT(shakeLoader: shakeLoader)
        sut.appear()
        sut.lineSettled(happyLine)
        schedule.fire()
        voice.finish()

        shakeLoader.shake()

        XCTAssertEqual(voice.stopCount, 0)
    }

    // MARK: - Helpers

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeSUT(
        defaults: DefaultsSpy = DefaultsSpy(),
        isEnabled: Bool = true,
        clock: ClockStub = ClockStub(at: Date(timeIntervalSince1970: 1_792_000_000)),
        shakeLoader: ShakeLoaderStub = ShakeLoaderStub(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantMonitorSproutViewModel, voice: VoiceSpy, schedule: ScheduleSpy, clock: ClockStub) {
        let voice = VoiceSpy()
        let schedule = ScheduleSpy()
        let sut = PlantMonitorSproutViewModel(
            voice: voice,
            spokenLines: PlantSpokenLineStore(defaults: defaults),
            isEnabled: { isEnabled },
            clock: clock.now,
            calendar: utcCalendar(),
            schedule: schedule.schedule,
            shakeLoader: shakeLoader,
            randomIndex: { _ in 0 }
        )
        trackMemoryLeak(shakeLoader, file: file, line: line)
        trackMemoryLeak(voice, file: file, line: line)
        trackMemoryLeak(schedule, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, voice, schedule, clock)
    }

    private final class ClockStub {
        private var date: Date
        init(at date: Date) { self.date = date }
        var now: () -> Date { { self.date } }
        func advance(by seconds: TimeInterval) { date = date.addingTimeInterval(seconds) }
    }
}
