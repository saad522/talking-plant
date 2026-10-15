import PlantShared
import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorViewModelTests: PlantMonitorXCTestCase {
    func test_init_doesNotMessageLoader() {
        let (_, loader, _) = makeSUT()

        XCTAssertEqual(loader.messages, [])
    }

    func test_init_hasLocalisedHistoryLabel() {
        let (sut, _, _) = makeSUT()

        XCTAssertEqual(sut.historyLabel, String.localised(key: "plant.monitor.history.label"))
    }

    func test_appear_subscribesToReadingsOnce() {
        let (sut, loader, _) = makeSUT()

        sut.appear()
        sut.appear()

        XCTAssertEqual(loader.messages, [.subscribeReadings])
    }

    func test_appear_deliversEveryReadingFromLoader() {
        let (sut, loader, _) = makeSUT()
        let first = makeReading(sequence: 1)
        let second = makeReading(sequence: 2)
        var received: [PlantReading] = []
        sut.loadedReading = { received.append($0) }

        sut.appear()
        loader.completeSubscription(with: first)
        loader.completeSubscription(with: second)

        XCTAssertEqual(received, [first, second])
    }

    func test_appear_deliversErrorFromLoader() {
        let (sut, loader, _) = makeSUT()
        var received: [NSError] = []
        sut.loadedError = { received.append($0 as NSError) }

        sut.appear()
        loader.completeSubscription(with: anyNSError())

        XCTAssertEqual(received, [anyNSError()])
    }

    func test_init_doesNotMessageConnectionLoader() {
        let connectionLoader = ConnectionLoaderStub()
        _ = makeSUTWithSpeech(connectionLoader: connectionLoader)

        XCTAssertEqual(connectionLoader.messages, [])
    }

    func test_appear_subscribesToConnectionOnce() {
        let connectionLoader = ConnectionLoaderStub()
        let (sut, _, _, _) = makeSUTWithSpeech(connectionLoader: connectionLoader)

        sut.appear()
        sut.appear()

        XCTAssertEqual(connectionLoader.messages, [.subscribeConnection])
    }

    func test_appear_deliversSceneWithLatestConnection() {
        let connectionLoader = ConnectionLoaderStub()
        let (sut, _, _, _) = makeSUTWithSpeech(connectionLoader: connectionLoader)
        var received: [PlantConnection?] = []
        sut.loadedScene = { received.append($0.connection) }

        sut.appear()
        connectionLoader.complete(with: .connecting)
        connectionLoader.complete(with: .connected)

        XCTAssertEqual(received, [.connecting, .connected])
    }

    func test_connectionUpdate_keepsReadingAndMood() {
        let connectionLoader = ConnectionLoaderStub()
        let (sut, loader, healthLoader, _) = makeSUTWithSpeech(connectionLoader: connectionLoader)
        let reading = makeReading()
        var scenes: [PlantMonitorSceneViewModel] = []
        sut.loadedScene = { scenes.append($0) }

        sut.appear()
        loader.completeSubscription(with: reading)
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))
        connectionLoader.complete(with: .offline)

        XCTAssertEqual(scenes.last?.reading, reading)
        XCTAssertEqual(scenes.last?.mood, .thirsty)
        XCTAssertEqual(scenes.last?.connection, .offline)
    }

    func test_connectionUpdate_doesNotRequestSpeechAgain() {
        let connectionLoader = ConnectionLoaderStub()
        let (sut, _, healthLoader, speechLoader) = makeSUTWithSpeech(connectionLoader: connectionLoader)

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))
        connectionLoader.complete(with: .offline)

        XCTAssertEqual(speechLoader.messages.count, 1)
    }

    func test_appear_doesNotDeliverConnectionAfterSUTIsReleased() {
        let connectionLoader = ConnectionLoaderStub()
        var sut: PlantMonitorViewModel? = PlantMonitorViewModel(
            loader: LoaderStub(),
            healthLoader: HealthLoaderStub(),
            connectionLoader: connectionLoader,
            speechLoader: SpeechLoaderStub(),
            plantName: "Sprout",
            clock: { self.anyDate() },
            calendar: .current,
            schedule: ScheduleSpy().schedule,
            actionHandler: { _ in }
        )
        var received: [PlantConnection?] = []
        sut?.loadedScene = { received.append($0.connection) }

        sut?.appear()
        sut = nil
        connectionLoader.complete(with: .connecting)

        XCTAssertEqual(received, [])
    }

    func test_init_doesNotMessageHealthLoader() {
        let (_, _, healthLoader) = makeSUT()

        XCTAssertEqual(healthLoader.messages, [])
    }

    func test_appear_loadsAndSubscribesToHealthOnce() {
        let (sut, _, healthLoader) = makeSUT()

        sut.appear()
        sut.appear()

        XCTAssertEqual(healthLoader.messages, [.loadHealth, .subscribeHealth])
    }

    func test_appear_deliversMoodOfLoadedHealth() {
        let (sut, _, healthLoader) = makeSUT()
        var received: [PlantMood] = []
        sut.loadedScene = { received.append(contentsOf: [$0.mood].compactMap { $0 }) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))

        XCTAssertEqual(received, [.thirsty])
    }

    func test_appear_deliversHappyMoodWithoutIssues() {
        let (sut, _, healthLoader) = makeSUT()
        var received: [PlantMood] = []
        sut.loadedScene = { received.append(contentsOf: [$0.mood].compactMap { $0 }) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))

        XCTAssertEqual(received, [.happy])
    }

    func test_healthUpdate_loadsHealthAgain() {
        let (sut, _, healthLoader) = makeSUT()
        var received: [PlantMood] = []
        sut.loadedScene = { received.append(contentsOf: [$0.mood].compactMap { $0 }) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))
        healthLoader.simulateUpdate()
        healthLoader.completeLoad(with: PlantHealth(score: 40, issues: [.veryThirsty]), at: 1)

        XCTAssertEqual(healthLoader.messages, [.loadHealth, .subscribeHealth, .loadHealth])
        XCTAssertEqual(received, [.happy, .veryThirsty])
    }

    func test_healthLoadFailure_doesNotDeliverMoodOrError() {
        let (sut, _, healthLoader) = makeSUT()
        var moods: [PlantMood] = []
        var errors: [Error] = []
        sut.loadedScene = { moods.append(contentsOf: [$0.mood].compactMap { $0 }) }
        sut.loadedError = { errors.append($0) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))
        healthLoader.simulateUpdate()
        healthLoader.completeLoad(with: anyNSError(), at: 1)

        XCTAssertEqual(moods, [.happy])
        XCTAssertEqual(errors.count, 0)
    }

    func test_appear_doesNotDeliverMoodAfterSUTIsReleased() {
        let healthLoader = HealthLoaderStub()
        var sut: PlantMonitorViewModel? = PlantMonitorViewModel(
            loader: LoaderStub(),
            healthLoader: healthLoader,
            connectionLoader: ConnectionLoaderStub(),
            speechLoader: SpeechLoaderStub(),
            plantName: "Sprout",
            clock: { self.anyDate() },
            calendar: .current,
            schedule: ScheduleSpy().schedule,
            actionHandler: { _ in }
        )
        var received: [PlantMood] = []
        sut?.loadedScene = { received.append(contentsOf: [$0.mood].compactMap { $0 }) }

        sut?.appear()
        sut = nil
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))

        XCTAssertEqual(received, [])
    }

    func test_historyTap_deliversHistoryTapAction() {
        var actions: [PlantMonitorAction] = []
        let (sut, _, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.historyTap()

        XCTAssertEqual(actions, [.historyTap])
    }

    func test_talkTap_deliversTalkTapAction() {
        var actions: [PlantMonitorAction] = []
        let (sut, _, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.talkTap()

        XCTAssertEqual(actions, [.talkTap])
    }

    func test_settingsTap_deliversSettingsTapAction() {
        var actions: [PlantMonitorAction] = []
        let (sut, _, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.settingsTap()

        XCTAssertEqual(actions, [.settingsTap])
    }

    func test_init_hasLocalisedSettingsLabel() {
        let (sut, _, _) = makeSUT()

        XCTAssertEqual(sut.settingsLabel, String.localised(key: "plant.monitor.settings.label"))
    }

    func test_waterTap_deliversWaterTapAction() {
        var actions: [PlantMonitorAction] = []
        let (sut, _, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.waterTap()

        XCTAssertEqual(actions, [.waterTap])
    }

    func test_init_hasLocalisedTalkAndWaterLabels() {
        let (sut, _, _) = makeSUT()

        XCTAssertEqual(sut.talkLabel, "Talk to Sprout")
        XCTAssertEqual(sut.waterLabel, String.localised(key: "plant.monitor.water.label"))
    }

    func test_appear_doesNotDeliverSceneBeforeReadingOrMood() {
        let (sut, _, _) = makeSUT()
        var scenes: [PlantMonitorScene] = []
        sut.loadedScene = { scenes.append($0.scene) }

        sut.appear()

        XCTAssertEqual(scenes, [])
    }

    func test_appear_deliversSceneOnReadingWithoutMood() {
        let (sut, loader, _) = makeSUT()
        var scenes: [PlantMonitorSceneViewModel] = []
        sut.loadedScene = { scenes.append($0) }
        let reading = makeReading(lux: 5)

        sut.appear()
        loader.completeSubscription(with: reading)

        XCTAssertEqual(scenes.map(\.scene), [.night])
        XCTAssertEqual(scenes.first?.reading, reading)
    }

    func test_appear_deliversSceneOnMoodWithoutReading() {
        let (sut, _, healthLoader) = makeSUT()
        var scenes: [PlantMonitorSceneViewModel] = []
        sut.loadedScene = { scenes.append($0) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 40, issues: [.veryThirsty]))

        XCTAssertEqual(scenes.map(\.scene), [.thirsty])
        XCTAssertNil(scenes.first?.reading)
    }

    func test_sceneUsesLatestReadingAndMood() {
        let (sut, loader, healthLoader) = makeSUT()
        var scenes: [PlantMonitorSceneViewModel] = []
        sut.loadedScene = { scenes.append($0) }
        let bright = makeReading(lux: 1_000)
        let dark = makeReading(lux: 2)

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))
        loader.completeSubscription(with: bright)
        loader.completeSubscription(with: dark)
        healthLoader.simulateUpdate()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []), at: 1)

        XCTAssertEqual(scenes.map(\.scene), [.thirsty, .thirsty, .night, .night])
        XCTAssertEqual(scenes.map(\.reading), [nil, bright, dark, dark])
        XCTAssertEqual(scenes.last?.warnings, [])
    }

    func test_appear_doesNotDeliverAfterSUTIsReleased() {
        let loader = LoaderStub()
        var sut: PlantMonitorViewModel? = PlantMonitorViewModel(loader: loader, healthLoader: HealthLoaderStub(), connectionLoader: ConnectionLoaderStub(), speechLoader: SpeechLoaderStub(), plantName: "Sprout", clock: { self.anyDate() }, calendar: .current, schedule: ScheduleSpy().schedule, actionHandler: { _ in })
        var received: [PlantReading] = []
        sut?.loadedReading = { received.append($0) }

        sut?.appear()
        sut = nil
        loader.completeSubscription(with: makeReading())

        XCTAssertEqual(received, [])
    }

    // MARK: - Speech

    func test_appear_doesNotLoadSpeechBeforeMood() {
        let (sut, loader, _, speechLoader) = makeSUTWithSpeech()

        sut.appear()
        loader.completeSubscription(with: makeReading())

        XCTAssertEqual(speechLoader.messages, [])
    }

    func test_mood_deliversTemplateLineAtOnceAndAsksSpeechLoader() {
        let (sut, loader, healthLoader, speechLoader) = makeSUTWithSpeech()
        var lines: [String] = []
        sut.loadedSpeech = { lines.append($0) }
        let reading = makeReading()

        sut.appear()
        loader.completeSubscription(with: reading)
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))

        XCTAssertEqual(lines, [PlantMoodViewModel(mood: .thirsty).speech])
        XCTAssertEqual(speechLoader.messages, [.init(mood: .thirsty, isSleeping: false, reading: reading)])
    }

    func test_speechLoad_deliversGeneratedLineAfterTemplate() {
        let (sut, _, healthLoader, speechLoader) = makeSUTWithSpeech()
        var lines: [String] = []
        sut.loadedSpeech = { lines.append($0) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))
        speechLoader.completeLoad(with: "Got any water?")

        XCTAssertEqual(lines, [PlantMoodViewModel(mood: .thirsty).speech, "Got any water?"])
    }

    func test_speechLoadFailure_keepsTemplateLine() {
        let (sut, _, healthLoader, speechLoader) = makeSUTWithSpeech()
        var lines: [String] = []
        sut.loadedSpeech = { lines.append($0) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))
        speechLoader.completeLoad(with: anyNSError())

        XCTAssertEqual(lines, [PlantMoodViewModel(mood: .thirsty).speech])
    }

    func test_speechLoad_ignoresResultForStaleKey() {
        let (sut, _, healthLoader, speechLoader) = makeSUTWithSpeech()
        var lines: [String] = []
        sut.loadedSpeech = { lines.append($0) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))
        healthLoader.simulateUpdate()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []), at: 1)
        speechLoader.completeLoad(with: "Stale thirsty line", at: 0)

        XCTAssertEqual(lines, [PlantMoodViewModel(mood: .thirsty).speech, PlantMoodViewModel(mood: .happy).speech])
    }

    func test_sceneChange_loadsSpeechAgain() {
        let (sut, loader, healthLoader, speechLoader) = makeSUTWithSpeech()
        let bright = makeReading(lux: 1_000)
        let dark = makeReading(lux: 2)

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))
        loader.completeSubscription(with: bright)
        loader.completeSubscription(with: dark)

        XCTAssertEqual(speechLoader.messages.map(\.isSleeping), [false, true])
    }

    func test_sceneChange_deliversSleepingTemplateLine() {
        let (sut, loader, healthLoader, _) = makeSUTWithSpeech()
        var lines: [String] = []
        sut.loadedSpeech = { lines.append($0) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))
        loader.completeSubscription(with: makeReading(lux: 2))

        XCTAssertEqual(lines, [PlantMoodViewModel(mood: .happy).speech, String.localised(key: "plant.monitor.sleeping.speech")])
    }

    func test_moodChange_loadsSpeechAgain() {
        let (sut, _, healthLoader, speechLoader) = makeSUTWithSpeech()

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))
        healthLoader.simulateUpdate()
        healthLoader.completeLoad(with: PlantHealth(score: 40, issues: [.tooHot]), at: 1)

        XCTAssertEqual(speechLoader.messages.map(\.mood), [.happy, .tooHot])
    }

    func test_newReadingWithSameKey_doesNotLoadSpeechAgain() {
        let (sut, loader, healthLoader, speechLoader) = makeSUTWithSpeech()
        var lines: [String] = []
        sut.loadedSpeech = { lines.append($0) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))
        loader.completeSubscription(with: makeReading(sequence: 1))
        loader.completeSubscription(with: makeReading(sequence: 2))
        healthLoader.simulateUpdate()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []), at: 1)

        XCTAssertEqual(speechLoader.messages.count, 1)
        XCTAssertEqual(lines.count, 1)
    }

    func test_speechLoad_doesNotDeliverAfterSUTIsReleased() {
        let healthLoader = HealthLoaderStub()
        let speechLoader = SpeechLoaderStub()
        var sut: PlantMonitorViewModel? = PlantMonitorViewModel(
            loader: LoaderStub(),
            healthLoader: healthLoader,
            connectionLoader: ConnectionLoaderStub(),
            speechLoader: speechLoader,
            plantName: "Sprout",
            clock: { self.anyDate() },
            calendar: .current,
            schedule: ScheduleSpy().schedule,
            actionHandler: { _ in }
        )
        var lines: [String] = []
        sut?.loadedSpeech = { lines.append($0) }

        sut?.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))
        sut = nil
        speechLoader.completeLoad(with: "Late line")

        XCTAssertEqual(lines, [PlantMoodViewModel(mood: .happy).speech])
    }

    // MARK: - Sky

    func test_init_doesNotScheduleOrDeliverSky() {
        let scheduleSpy = ScheduleSpy()
        let (sut, _, _, _) = makeSUTWithSpeech(scheduleSpy: scheduleSpy)
        var skies = 0
        sut.loadedSky = { _ in skies += 1 }

        XCTAssertEqual(scheduleSpy.intervals, [])
        XCTAssertEqual(skies, 0)
    }

    func test_appear_schedulesSkyTickEverySixtySecondsOnce() {
        let scheduleSpy = ScheduleSpy()
        let (sut, _, _, _) = makeSUTWithSpeech(scheduleSpy: scheduleSpy)

        sut.appear()
        sut.appear()

        XCTAssertEqual(scheduleSpy.intervals, [60])
    }

    func test_scene_deliversSkyForSceneAndClock() {
        let clock = ClockStub(at: noon())
        let (sut, loader, _, _) = makeSUTWithSpeech(clock: clock.now)
        var skies: [(PlantMonitorSkyViewModel.Body, Double, Bool)] = []
        sut.loadedSky = { skies.append(($0.sky.body, $0.sky.progress, $0.isGradual)) }

        sut.appear()
        loader.completeSubscription(with: makeReading(lux: 1_000))

        XCTAssertEqual(skies.count, 1)
        XCTAssertEqual(skies.first?.0, .sun)
        XCTAssertEqual(skies.first?.1 ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(skies.first?.2, false)
    }

    func test_tick_beforeAnySceneDeliversNoSky() {
        let scheduleSpy = ScheduleSpy()
        let (sut, _, _, _) = makeSUTWithSpeech(scheduleSpy: scheduleSpy)
        var skies = 0
        sut.loadedSky = { _ in skies += 1 }

        sut.appear()
        scheduleSpy.fire()

        XCTAssertEqual(skies, 0)
    }

    func test_tick_aMinuteLaterDeliversGradualSky() {
        let clock = ClockStub(at: noon())
        let scheduleSpy = ScheduleSpy()
        let (sut, loader, _, _) = makeSUTWithSpeech(clock: clock.now, scheduleSpy: scheduleSpy)
        var skies: [(Double, Bool)] = []
        sut.loadedSky = { skies.append(($0.sky.progress, $0.isGradual)) }
        sut.appear()
        loader.completeSubscription(with: makeReading(lux: 1_000))

        clock.advance(by: 60)
        scheduleSpy.fire()

        XCTAssertEqual(skies.count, 2)
        XCTAssertEqual(skies.last?.0 ?? -1, 0.5 + 1.0 / 720, accuracy: 0.0001)
        XCTAssertEqual(skies.last?.1, true)
    }

    func test_tick_keepsTickingWhileSUTLives() {
        let scheduleSpy = ScheduleSpy()
        let (sut, _, _, _) = makeSUTWithSpeech(scheduleSpy: scheduleSpy)
        sut.appear()

        XCTAssertTrue(scheduleSpy.fire())
    }

    func test_sceneChangeFromSunToMoon_isNotGradual() {
        let clock = ClockStub(at: noon())
        let (sut, loader, _, _) = makeSUTWithSpeech(clock: clock.now)
        var skies: [(PlantMonitorSkyViewModel.Body, Bool)] = []
        sut.loadedSky = { skies.append(($0.sky.body, $0.isGradual)) }
        sut.appear()
        loader.completeSubscription(with: makeReading(lux: 1_000))

        loader.completeSubscription(with: makeReading(lux: 3))

        XCTAssertEqual(skies.last?.0, .moon)
        XCTAssertEqual(skies.last?.1, false)
    }

    func test_tick_afterThreeHourJumpIsNotGradual() {
        let clock = ClockStub(at: noon())
        let scheduleSpy = ScheduleSpy()
        let (sut, loader, _, _) = makeSUTWithSpeech(clock: clock.now, scheduleSpy: scheduleSpy)
        var skies: [Bool] = []
        sut.loadedSky = { skies.append($0.isGradual) }
        sut.appear()
        loader.completeSubscription(with: makeReading(lux: 1_000))

        clock.advance(by: 3 * 3_600)
        scheduleSpy.fire()

        XCTAssertEqual(skies.last, false)
    }

    func test_tick_stopsOnceSUTIsReleased() {
        let scheduleSpy = ScheduleSpy()
        let loader = LoaderStub()
        var sut: PlantMonitorViewModel? = PlantMonitorViewModel(
            loader: loader,
            healthLoader: HealthLoaderStub(),
            connectionLoader: ConnectionLoaderStub(),
            speechLoader: SpeechLoaderStub(),
            plantName: "Sprout",
            clock: { self.anyDate() },
            calendar: utcCalendar(),
            schedule: scheduleSpy.schedule,
            actionHandler: { _ in }
        )
        sut?.appear()
        trackMemoryLeak(loader)

        sut = nil

        XCTAssertFalse(scheduleSpy.fire())
    }

    // MARK: - Private helpers

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func noon() -> Date {
        Date(timeIntervalSince1970: 12 * 3_600)
    }

    private final class ClockStub {
        private var date: Date
        init(at date: Date) { self.date = date }
        var now: () -> Date { { self.date } }
        func advance(by seconds: TimeInterval) { date = date.addingTimeInterval(seconds) }
    }

    private func makeSUT(
        actionHandler: @escaping (PlantMonitorAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantMonitorViewModel, loader: LoaderStub, healthLoader: HealthLoaderStub) {
        let (sut, loader, healthLoader, _) = makeSUTWithSpeech(actionHandler: actionHandler, file: file, line: line)
        return (sut, loader, healthLoader)
    }

    private func makeSUTWithSpeech(
        connectionLoader: ConnectionLoaderStub = ConnectionLoaderStub(),
        clock: @escaping () -> Date = { Date(timeIntervalSince1970: 1_000) },
        scheduleSpy: ScheduleSpy = ScheduleSpy(),
        actionHandler: @escaping (PlantMonitorAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantMonitorViewModel, loader: LoaderStub, healthLoader: HealthLoaderStub, speechLoader: SpeechLoaderStub) {
        let loader = LoaderStub()
        let healthLoader = HealthLoaderStub()
        let speechLoader = SpeechLoaderStub()
        let sut = PlantMonitorViewModel(
            loader: loader,
            healthLoader: healthLoader,
            connectionLoader: connectionLoader,
            speechLoader: speechLoader,
            plantName: "Sprout",
            clock: clock,
            calendar: utcCalendar(),
            schedule: scheduleSpy.schedule,
            actionHandler: actionHandler
        )
        trackMemoryLeak(connectionLoader, file: file, line: line)
        trackMemoryLeak(loader, file: file, line: line)
        trackMemoryLeak(healthLoader, file: file, line: line)
        trackMemoryLeak(speechLoader, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, loader, healthLoader, speechLoader)
    }
}
