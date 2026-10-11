import PlantMonitor
import PlantMonitoriOS
import PlantShared
import XCTest

@MainActor
final class PlantMonitorUIITests: PlantMonitoriOSXCTestCase {
    func test_init_doesNotMessageLoader() {
        let (_, loader, _) = makeSUT()

        XCTAssertEqual(loader.messages, [])
    }

    func test_init_displaysLoadingWithoutChipsOrError() {
        let (sut, _, _) = makeSUT()

        XCTAssertTrue(sut.isLoading)
        XCTAssertEqual(sut.renderedChips().count, 0)
        XCTAssertNil(sut.renderedError())
    }

    func test_init_rendersTitleAndRoomBeforeMoodLoads() {
        let (sut, _, _) = makeSUT()

        XCTAssertEqual(sut.title, "Sprout")
        XCTAssertEqual(sut.subtitle, "Living room")
        XCTAssertNil(sut.bubbleText)
    }

    func test_init_rendersSunAndNoButtonsYet() {
        let (sut, _, _) = makeSUT()

        XCTAssertEqual(sut.celestial, .sun)
        XCTAssertEqual(sut.renderedButtons().count, 0)
    }

    func test_appear_subscribesToReadingsOnce() {
        let (sut, loader, _) = makeSUT()

        sut.simulateAppear()
        sut.simulateAppear()

        XCTAssertEqual(loader.messages, [.subscribeReadings])
    }

    func test_appear_rendersThreeChipsWithValuesOnReading() {
        let (sut, loader, _) = makeSUT()
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
        let (sut, loader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(moisture: 42))
        loader.completeSubscription(with: makeReading(moisture: 38))

        XCTAssertEqual(sut.renderedChips().first?.value, "38%")
    }

    func test_appear_rendersPlaceholdersForMissingValues() {
        let (sut, loader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(moisture: nil, lux: nil, temperature: nil, humidity: nil))

        XCTAssertEqual(sut.renderedChips().map(\.value), ["–", "–", "–"])
    }

    func test_appear_rendersMoistureWarningWhenThirsty() {
        let (sut, loader, healthLoader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading())
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))

        XCTAssertEqual(sut.renderedChips().map(\.kind), [.moisture, .light, .temperature])
        XCTAssertEqual(sut.renderedChips().map(\.isWarning), [true, false, false])
    }

    func test_appear_rendersNoWarningWhenHappy() {
        let (sut, loader, healthLoader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading())
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))

        XCTAssertEqual(sut.renderedChips().map(\.isWarning), [false, false, false])
    }

    func test_appear_rendersHumidityChipWithWarningForDryAir() {
        let (sut, loader, healthLoader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(moisture: 42, lux: 1_200, humidity: 20))
        healthLoader.completeLoad(with: PlantHealth(score: 80, issues: [.dryAir]))

        XCTAssertEqual(sut.renderedChips().map(\.kind), [.moisture, .light, .humidity])
        XCTAssertEqual(sut.renderedChips().map(\.value), ["42%", "1,200 lx", "20%"])
        XCTAssertEqual(sut.renderedChips().map(\.isWarning), [false, false, true])
    }

    func test_appear_keepsLoadingWhenOnlyMoodArrives() {
        let (sut, _, healthLoader) = makeSUT()

        sut.simulateAppear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))

        XCTAssertTrue(sut.isLoading)
        XCTAssertEqual(sut.renderedChips().count, 0)
    }

    func test_appear_displaysConnectivityErrorOnFailure() {
        let (sut, loader, _) = makeSUT()

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
        let (sut, loader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: PeripheralPlantReadingLoader.Error.invalidData)

        XCTAssertEqual(
            sut.renderedError()?.description,
            String.localised(key: "plant.monitor.general.error.description")
        )
    }

    func test_appear_hidesErrorOnNextReading() {
        let (sut, loader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: anyNSError())
        loader.completeSubscription(with: makeReading())

        XCTAssertNil(sut.renderedError())
        XCTAssertEqual(sut.renderedChips().count, 3)
    }

    func test_error_deliversDismissedAction() {
        let exp = expectation(description: "wait for action")
        var invokedActions: [PlantMonitorAction] = []
        let (sut, loader, _) = makeSUT(actionHandler: {
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
        let (sut, _, healthLoader) = makeSUT()

        XCTAssertEqual(healthLoader.messages, [])
        XCTAssertNil(sut.renderedFace())
        XCTAssertNil(sut.bubbleText)
    }

    func test_appear_loadsAndSubscribesToHealthOnce() {
        let (sut, _, healthLoader) = makeSUT()

        sut.simulateAppear()
        sut.simulateAppear()

        XCTAssertEqual(healthLoader.messages, [.loadHealth, .subscribeHealth])
    }

    func test_appear_rendersFaceBubbleAndSubtitleOnceHealthLoads() {
        let (sut, _, healthLoader) = makeSUT()

        sut.simulateAppear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))

        XCTAssertEqual(sut.renderedFace(), FaceStub(mood: .thirsty))
        XCTAssertEqual(sut.bubbleText, "I could use a drink soon.")
        XCTAssertEqual(sut.subtitle, "Living room · Thirsty")
    }

    func test_appear_rendersBubbleTextForEveryMood() {
        let issues: [PlantMood: [PlantHealthIssue]] = [
            .happy: [], .thirsty: [.thirsty], .veryThirsty: [.veryThirsty], .drowning: [.drowning],
            .tooDark: [.tooDark], .tooHot: [.tooHot], .tooCold: [.tooCold], .dryAir: [.dryAir],
        ]

        issues.forEach { mood, issues in
            let (sut, _, healthLoader) = makeSUT()

            sut.simulateAppear()
            healthLoader.completeLoad(with: PlantHealth(score: 50, issues: issues))

            XCTAssertEqual(sut.bubbleText, PlantMoodViewModel(mood: mood).speech, "\(mood)")
        }
    }

    func test_healthUpdate_rendersNewFaceBubbleAndSubtitle() {
        let (sut, _, healthLoader) = makeSUT()

        sut.simulateAppear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))
        healthLoader.simulateUpdate()
        healthLoader.completeLoad(with: PlantHealth(score: 40, issues: [.veryThirsty]), at: 1)

        XCTAssertEqual(sut.renderedFace(), FaceStub(mood: .veryThirsty))
        XCTAssertEqual(sut.bubbleText, "Water, please! I'm parched.")
        XCTAssertEqual(sut.subtitle, "Living room · Very thirsty")
    }

    func test_healthLoadFailure_keepsLastMood() {
        let (sut, _, healthLoader) = makeSUT()

        sut.simulateAppear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))
        healthLoader.simulateUpdate()
        healthLoader.completeLoad(with: anyNSError(), at: 1)

        XCTAssertEqual(sut.renderedFace(), FaceStub(mood: .thirsty))
        XCTAssertNil(sut.renderedError())
    }

    func test_scene_rendersSunByDayAndMoonAtNight() {
        let (sut, loader, _) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(lux: 1_000))
        XCTAssertEqual(sut.celestial, .sun)

        loader.completeSubscription(with: makeReading(lux: 3))
        XCTAssertEqual(sut.celestial, .moon)
    }

    func test_scene_rendersMoonWhenOffline() {
        let (sut, _, healthLoader) = makeSUT()

        sut.simulateAppear()
        healthLoader.completeLoad(with: PlantHealth(score: 0, issues: [.offline]))

        XCTAssertEqual(sut.celestial, .moon)
    }

    func test_scene_rendersTalkAsPrimaryButtonByDay() {
        let (sut, loader, healthLoader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading())
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))

        XCTAssertEqual(sut.renderedButtons().map(\.title), ["Talk to Sprout", "Water", "History"])
        XCTAssertEqual(sut.renderedButtons().map(\.style), [.primary, .secondary, .secondary])
    }

    func test_scene_rendersWaterAsPrimaryButtonWhenThirsty() {
        let (sut, loader, healthLoader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading())
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))

        XCTAssertEqual(sut.renderedButtons().map(\.title), ["Water", "Talk to Sprout", "History"])
        XCTAssertEqual(sut.renderedButtons().map(\.style), [.primary, .secondary, .secondary])
    }

    func test_scene_rendersTalkAsPrimaryButtonAtNightEvenWhenThirsty() {
        let (sut, loader, healthLoader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(lux: 0))
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))

        XCTAssertEqual(sut.renderedButtons().first?.title, "Talk to Sprout")
        XCTAssertEqual(sut.renderedChips().map(\.isWarning), [true, false, false])
    }

    func test_buttons_deliverActions() {
        var invokedActions: [PlantMonitorAction] = []
        let (sut, loader, _) = makeSUT(actionHandler: { invokedActions.append($0) })

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading())
        sut.simulateTap(onButton: "Talk to Sprout")
        sut.simulateTap(onButton: "Water")
        sut.simulateTap(onButton: "History")

        XCTAssertEqual(invokedActions, [.talkTap, .waterTap, .historyTap])
    }
}
