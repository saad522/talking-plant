import PlantMonitor
import PlantMonitoriOS
import PlantShared
import XCTest

@MainActor
final class PlantMonitorUIITests: PlantMonitoriOSXCTestCase {
    func test_init_doesNotMessageLoader() {
        let (_, loader, _, _) = makeSUT()

        XCTAssertEqual(loader.messages, [])
    }

    func test_init_displaysLoadingWithoutChipsOrError() {
        let (sut, _, _, _) = makeSUT()

        XCTAssertTrue(sut.isLoading)
        XCTAssertEqual(sut.renderedChips().count, 0)
        XCTAssertNil(sut.renderedError())
    }

    func test_init_rendersTitleAndRoomBeforeMoodLoads() {
        let (sut, _, _, _) = makeSUT()

        XCTAssertEqual(sut.title, "Sprout")
        XCTAssertEqual(sut.subtitle, "Living room")
        XCTAssertNil(sut.bubbleText)
    }

    func test_init_rendersSunAndNoButtonsYet() {
        let (sut, _, _, _) = makeSUT()

        XCTAssertEqual(sut.celestial, .sun)
        XCTAssertEqual(sut.renderedButtons().count, 0)
    }

    func test_appear_subscribesToConnectionOnce() {
        let (sut, _, _, connectionLoader) = makeSUT()

        sut.simulateAppear()
        sut.simulateAppear()

        XCTAssertEqual(connectionLoader.messages, [.subscribeConnection])
    }

    func test_connection_rendersConnectingSubtitleBeforeAnyReading() {
        let (sut, _, _, connectionLoader) = makeSUT()

        sut.simulateAppear()
        connectionLoader.complete(with: .connecting)

        XCTAssertEqual(sut.subtitle, "Living room · Connecting…")
        XCTAssertTrue(sut.isLoading)
    }

    func test_connection_rendersConnectionInsteadOfMood() {
        let (sut, loader, healthLoader, connectionLoader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading())
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))
        connectionLoader.complete(with: .offline)
        XCTAssertEqual(sut.subtitle, "Living room · Sensor offline")

        connectionLoader.complete(with: .connected)
        XCTAssertEqual(sut.subtitle, "Living room · Thirsty")
    }

    func test_settingsButton_deliversSettingsTapAction() {
        var invokedActions: [PlantMonitorAction] = []
        let (sut, _, _, _) = makeSUT(actionHandler: { invokedActions.append($0) })

        sut.simulateTapOnSettings()

        XCTAssertEqual(invokedActions, [.settingsTap])
    }

    func test_settingsButton_hasLocalisedAccessibilityLabel() {
        let (sut, _, _, _) = makeSUT()

        XCTAssertEqual(sut.settingsLabel, String.localised(key: "plant.monitor.settings.label"))
    }

    func test_appear_subscribesToReadingsOnce() {
        let (sut, loader, _, _) = makeSUT()

        sut.simulateAppear()
        sut.simulateAppear()

        XCTAssertEqual(loader.messages, [.subscribeReadings])
    }

    func test_appear_rendersThreeChipsWithValuesOnReading() {
        let (sut, loader, _, _) = makeSUT()
        let reading = makeReading(moisture: 42, lux: 1_200, temperature: 21.5, humidity: 60)

        sut.simulateAppear()
        loader.completeSubscription(with: reading)

        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.renderedChips().map(\.title), [
            String.localised(key: "plant.monitor.moisture.title"),
            String.localised(key: "plant.monitor.light.title"),
            String.localised(key: "plant.monitor.temperature.title"),
        ])
        XCTAssertEqual(sut.renderedChips().map(\.value), ["42%", "1,200 lx", "21.5 °C"])
        XCTAssertEqual(sut.renderedChips().map(\.isWarning), [false, false, false])
    }

    func test_appear_rendersLatestReadingOnEveryUpdate() {
        let (sut, loader, _, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(moisture: 42))
        loader.completeSubscription(with: makeReading(moisture: 38))

        XCTAssertEqual(sut.renderedChips().first?.value, "38%")
    }

    func test_appear_rendersPlaceholdersForMissingValues() {
        let (sut, loader, _, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(moisture: nil, lux: nil, temperature: nil, humidity: nil))

        XCTAssertEqual(sut.renderedChips().map(\.value), ["–", "–", "–"])
    }

    func test_appear_rendersMoistureWarningWhenThirsty() {
        let (sut, loader, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading())
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))

        XCTAssertEqual(sut.renderedChips().map(\.kind), [.moisture, .light, .temperature])
        XCTAssertEqual(sut.renderedChips().map(\.isWarning), [true, false, false])
    }

    func test_appear_rendersNoWarningWhenHappy() {
        let (sut, loader, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading())
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))

        XCTAssertEqual(sut.renderedChips().map(\.isWarning), [false, false, false])
    }

    func test_appear_rendersHumidityChipWithWarningForDryAir() {
        let (sut, loader, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(moisture: 42, lux: 1_200, humidity: 20))
        healthLoader.completeLoad(with: PlantHealth(score: 80, issues: [.dryAir]))

        XCTAssertEqual(sut.renderedChips().map(\.kind), [.moisture, .light, .humidity])
        XCTAssertEqual(sut.renderedChips().map(\.value), ["42%", "1,200 lx", "20%"])
        XCTAssertEqual(sut.renderedChips().map(\.isWarning), [false, false, true])
    }

    func test_appear_keepsLoadingWhenOnlyMoodArrives() {
        let (sut, _, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))

        XCTAssertTrue(sut.isLoading)
        XCTAssertEqual(sut.renderedChips().count, 0)
    }

    func test_appear_displaysConnectivityErrorOnFailure() {
        let (sut, loader, _, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: PeripheralPlantReadingLoader.Error.connectivity)

        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(
            sut.renderedError()?.description,
            String.localised(key: "plant.monitor.connectivity.error.description")
        )
        XCTAssertEqual(sut.renderedError()?.buttonTitle, String.localised(key: "plant.monitor.error.dismiss.label"))
    }

    func test_appear_displaysGeneralErrorOnOtherFailure() {
        let (sut, loader, _, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: PeripheralPlantReadingLoader.Error.invalidData)

        XCTAssertEqual(
            sut.renderedError()?.description,
            String.localised(key: "plant.monitor.general.error.description")
        )
    }

    func test_appear_hidesErrorOnNextReading() {
        let (sut, loader, _, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: anyNSError())
        loader.completeSubscription(with: makeReading())

        XCTAssertNil(sut.renderedError())
        XCTAssertEqual(sut.renderedChips().count, 3)
    }

    func test_error_deliversDismissedAction() {
        let exp = expectation(description: "wait for action")
        var invokedActions: [PlantMonitorAction] = []
        let (sut, loader, _, _) = makeSUT(actionHandler: {
            invokedActions.append($0)
            exp.fulfill()
        })

        sut.simulateAppear()
        loader.completeSubscription(with: anyNSError())
        sut.renderedError()?.simulateTap()
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(invokedActions, [.dismissed])
    }

    func test_init_doesNotMessageHealthLoaderOrRenderMood() {
        let (sut, _, healthLoader, _) = makeSUT()

        XCTAssertEqual(healthLoader.messages, [])
        XCTAssertNil(sut.renderedFace())
        XCTAssertNil(sut.bubbleText)
    }

    func test_appear_loadsAndSubscribesToHealthOnce() {
        let (sut, _, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        sut.simulateAppear()

        XCTAssertEqual(healthLoader.messages, [.loadHealth, .subscribeHealth])
    }

    func test_appear_rendersFaceBubbleAndSubtitleOnceHealthLoads() {
        let (sut, _, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))

        XCTAssertEqual(sut.renderedFace(), FaceStub(mood: .thirsty))
        XCTAssertEqual(sut.bubbleText, "I could use a drink soon.")
        XCTAssertEqual(sut.subtitle, "Living room · Thirsty")
    }

    func test_appear_replacesTemplateBubbleWithGeneratedLine() {
        let speechLoader = SpeechLoaderStub()
        let (sut, _, healthLoader, _) = makeSUT(speechLoader: speechLoader)

        sut.simulateAppear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))
        XCTAssertEqual(sut.bubbleText, "I could use a drink soon.")
        XCTAssertEqual(speechLoader.requestCount, 1)

        speechLoader.complete(with: "My soil feels dusty, friend.")

        XCTAssertEqual(sut.bubbleText, "My soil feels dusty, friend.")
    }

    func test_appear_rendersBubbleTextForEveryMood() {
        let issues: [PlantMood: [PlantHealthIssue]] = [
            .happy: [], .thirsty: [.thirsty], .veryThirsty: [.veryThirsty], .drowning: [.drowning],
            .tooDark: [.tooDark], .tooHot: [.tooHot], .tooCold: [.tooCold], .dryAir: [.dryAir],
        ]

        issues.forEach { mood, issues in
            let (sut, _, healthLoader, _) = makeSUT()

            sut.simulateAppear()
            healthLoader.completeLoad(with: PlantHealth(score: 50, issues: issues))

            XCTAssertEqual(sut.bubbleText, PlantMoodViewModel(mood: mood).speech, "\(mood)")
        }
    }

    func test_healthUpdate_rendersNewFaceBubbleAndSubtitle() {
        let (sut, _, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))
        healthLoader.simulateUpdate()
        healthLoader.completeLoad(with: PlantHealth(score: 40, issues: [.veryThirsty]), at: 1)

        XCTAssertEqual(sut.renderedFace(), FaceStub(mood: .veryThirsty))
        XCTAssertEqual(sut.bubbleText, "Water, please! I'm parched.")
        XCTAssertEqual(sut.subtitle, "Living room · Very thirsty")
    }

    func test_healthLoadFailure_keepsLastMood() {
        let (sut, _, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))
        healthLoader.simulateUpdate()
        healthLoader.completeLoad(with: anyNSError(), at: 1)

        XCTAssertEqual(sut.renderedFace(), FaceStub(mood: .thirsty))
        XCTAssertNil(sut.renderedError())
    }

    func test_scene_rendersSleepingPlantWhenHappyAtNight() {
        let (sut, loader, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(lux: 3))
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))

        XCTAssertEqual(sut.renderedFace(), FaceStub(mood: PlantMonitorSceneViewModel.sleepingFaceMood))
        XCTAssertEqual(sut.bubbleText, "Zzz… see you at sunrise.")
        XCTAssertEqual(sut.subtitle, "Living room · Sleeping")
    }

    func test_scene_wakesPlantToComplainAtNight() {
        let (sut, loader, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(lux: 3))
        healthLoader.completeLoad(with: PlantHealth(score: 40, issues: [.tooHot]))

        XCTAssertEqual(sut.renderedFace(), FaceStub(mood: .tooHot))
        XCTAssertEqual(sut.bubbleText, "Phew, it's hot in here.")
        XCTAssertEqual(sut.subtitle, "Living room · Too hot")
    }

    func test_scene_rendersSunByDayAndMoonAtNight() {
        let (sut, loader, _, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(lux: 1_000))
        XCTAssertEqual(sut.celestial, .sun)

        loader.completeSubscription(with: makeReading(lux: 3))
        XCTAssertEqual(sut.celestial, .moon)
    }

    func test_init_rendersLastSceneBeforeAnyUpdate() {
        XCTAssertEqual(makeSUT(lastScene: .night).sut.celestial, .moon)
        XCTAssertEqual(makeSUT(lastScene: .day).sut.celestial, .sun)
    }

    func test_scene_rendersMoonWhenOffline() {
        let (sut, _, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        healthLoader.completeLoad(with: PlantHealth(score: 0, issues: [.offline]))

        XCTAssertEqual(sut.celestial, .moon)
    }

    func test_sky_rendersSunHalfwayAtNoon() {
        let (sut, loader, _, _) = makeSUT(clock: ClockStub(at: time(hour: 12)))

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(lux: 1_000))

        XCTAssertEqual(sut.celestial, .sun)
        XCTAssertEqual(sut.skyProgress ?? -1, 0.5, accuracy: 0.0001)
    }

    func test_sky_rendersMoonForNightReadingAtItsClockPosition() {
        let (sut, loader, _, _) = makeSUT(clock: ClockStub(at: time(hour: 0)))

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(lux: 3))

        XCTAssertEqual(sut.celestial, .moon)
        XCTAssertEqual(sut.skyProgress ?? -1, 0.5, accuracy: 0.0001)
    }

    func test_init_rendersRememberedSceneAtCurrentTimeBeforeAnyUpdate() {
        let (sut, _, _, _) = makeSUT(lastScene: .day, clock: ClockStub(at: time(hour: 9)))

        XCTAssertEqual(sut.celestial, .sun)
        XCTAssertEqual(sut.skyProgress ?? -1, 0.25, accuracy: 0.0001)
        XCTAssertEqual(sut.skyIsGradual, false)
    }

    func test_sky_tickUpdatesProgressGradually() {
        let scheduleSpy = ScheduleSpy()
        let clock = ClockStub(at: time(hour: 12))
        let (sut, loader, _, _) = makeSUT(clock: clock, scheduleSpy: scheduleSpy)
        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(lux: 1_000))
        XCTAssertEqual(sut.skyProgress ?? -1, 0.5, accuracy: 0.0001)

        clock.advance(by: 60)
        scheduleSpy.fire()

        XCTAssertEqual(sut.skyProgress ?? -1, 0.5 + 1.0 / 720, accuracy: 0.0001)
        XCTAssertEqual(sut.skyIsGradual, true)
    }

    func test_scene_rendersTalkAsPrimaryButtonByDay() {
        let (sut, loader, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading())
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))

        XCTAssertEqual(sut.renderedButtons().map(\.title), ["Talk to Sprout", "Water", "History"])
        XCTAssertEqual(sut.renderedButtons().map(\.style), [.primary, .secondary, .secondary])
    }

    func test_scene_rendersWaterAsPrimaryButtonWhenThirsty() {
        let (sut, loader, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading())
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))

        XCTAssertEqual(sut.renderedButtons().map(\.title), ["Water", "Talk to Sprout", "History"])
        XCTAssertEqual(sut.renderedButtons().map(\.style), [.primary, .secondary, .secondary])
    }

    func test_scene_rendersWaterAsPrimaryButtonAtNightWhenThirsty() {
        let (sut, loader, healthLoader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(lux: 0))
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))

        XCTAssertEqual(sut.renderedButtons().map(\.title), ["Water", "Talk to Sprout", "History"])
        XCTAssertEqual(sut.renderedButtons().map(\.style), [.primary, .secondary, .secondary])
        XCTAssertEqual(sut.renderedChips().map(\.isWarning), [true, false, false])
    }

    func test_buttons_deliverActions() {
        var invokedActions: [PlantMonitorAction] = []
        let (sut, loader, _, _) = makeSUT(actionHandler: { invokedActions.append($0) })

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading())
        sut.simulateTap(onButton: "Talk to Sprout")
        sut.simulateTap(onButton: "Water")
        sut.simulateTap(onButton: "History")

        XCTAssertEqual(invokedActions, [.talkTap, .waterTap, .historyTap])
    }

    func test_buttons_playTapHapticBeforeEachAction() {
        for title in ["Talk to Sprout", "Water", "History"] {
            var invokedActions: [PlantMonitorAction] = []
            let haptics = HapticsSpy()
            let (sut, loader, _, _) = makeSUT(haptics: haptics, actionHandler: { invokedActions.append($0) })
            sut.simulateAppear()
            loader.completeSubscription(with: makeReading())

            sut.simulateTap(onButton: title)

            XCTAssertEqual(haptics.played, [.tap], title)
            XCTAssertEqual(invokedActions.count, 1, title)
        }
    }

    func test_settingsButton_playsTapHapticAndStillDeliversAction() {
        var invokedActions: [PlantMonitorAction] = []
        let haptics = HapticsSpy()
        let (sut, _, _, _) = makeSUT(haptics: haptics, actionHandler: { invokedActions.append($0) })

        sut.simulateTapOnSettings()

        XCTAssertEqual(haptics.played, [.tap])
        XCTAssertEqual(invokedActions, [.settingsTap])
    }

    func test_loadingReadingMoodAndScene_playsNoHaptic() {
        let haptics = HapticsSpy()
        let (sut, loader, healthLoader, connectionLoader) = makeSUT(haptics: haptics)

        sut.simulateAppear()
        connectionLoader.complete(with: .connected)
        loader.completeSubscription(with: makeReading())
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))
        loader.completeSubscription(with: makeReading(lux: 2))

        XCTAssertEqual(haptics.played, [])
    }

    func test_errorDismiss_playsTapAndStillDeliversDismissed() {
        var invokedActions: [PlantMonitorAction] = []
        let haptics = HapticsSpy()
        let (sut, loader, _, _) = makeSUT(haptics: haptics, actionHandler: { invokedActions.append($0) })
        sut.simulateAppear()
        loader.completeSubscription(with: anyNSError())
        XCTAssertEqual(haptics.played, [])

        sut.renderedError()?.simulateTap()

        XCTAssertEqual(haptics.played, [.tap])
        XCTAssertEqual(invokedActions, [.dismissed])
    }
}
