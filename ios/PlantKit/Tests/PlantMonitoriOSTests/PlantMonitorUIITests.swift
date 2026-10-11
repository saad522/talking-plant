import PlantMonitor
import PlantMonitoriOS
import PlantShared
import XCTest

@MainActor
final class PlantMonitorUIITests: PlantMonitoriOSXCTestCase {
    func test_init_doesNotMessageLoader() {
        let (_, loader) = makeSUT()

        XCTAssertEqual(loader.messages, [])
    }

    func test_init_displaysLoadingWithoutCardsOrError() {
        let (sut, _) = makeSUT()

        XCTAssertTrue(sut.isLoading)
        XCTAssertEqual(sut.renderedCards().count, 0)
        XCTAssertNil(sut.renderedError())
    }

    func test_init_rendersLocalisedHistoryLabel() {
        let (sut, _) = makeSUT()

        XCTAssertEqual(sut.historyLabel, String.localised(key: "plant.monitor.history.label"))
    }

    func test_appear_subscribesToReadingsOnce() {
        let (sut, loader) = makeSUT()

        sut.simulateAppear()
        sut.simulateAppear()

        XCTAssertEqual(loader.messages, [.subscribeReadings])
    }

    func test_appear_rendersSensorCardsOnReading() {
        let (sut, loader) = makeSUT()
        let reading = makeReading(moisture: 42, lux: 1_200, temperature: 21.5, humidity: 60)

        sut.simulateAppear()
        loader.completeSubscription(with: reading)

        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.renderedCards().map(\.title), [
            String.localised(key: "plant.monitor.moisture.title"),
            String.localised(key: "plant.monitor.light.title"),
            String.localised(key: "plant.monitor.temperature.title"),
            String.localised(key: "plant.monitor.humidity.title"),
        ])
        XCTAssertEqual(sut.renderedCards().map(\.value), ["42%", "1,200 lx", "21.5 °C", "60%"])
    }

    func test_appear_rendersLatestReadingOnEveryUpdate() {
        let (sut, loader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(moisture: 42))
        loader.completeSubscription(with: makeReading(moisture: 38))

        XCTAssertEqual(sut.renderedCards().first?.value, "38%")
    }

    func test_appear_rendersPlaceholdersForMissingValues() {
        let (sut, loader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: makeReading(moisture: nil, lux: nil, temperature: nil, humidity: nil))

        XCTAssertEqual(sut.renderedCards().map(\.value), ["–", "–", "–", "–"])
    }

    func test_appear_displaysConnectivityErrorOnFailure() {
        let (sut, loader) = makeSUT()

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
        let (sut, loader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: PeripheralPlantReadingLoader.Error.invalidData)

        XCTAssertEqual(
            sut.renderedError()?.description,
            String.localised(key: "plant.monitor.general.error.description")
        )
    }

    func test_appear_hidesErrorOnNextReading() {
        let (sut, loader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: anyNSError())
        loader.completeSubscription(with: makeReading())

        XCTAssertNil(sut.renderedError())
        XCTAssertEqual(sut.renderedCards().count, 4)
    }

    func test_error_deliversDismissedAction() {
        let exp = expectation(description: "wait for action")
        var invokedActions: [PlantMonitorAction] = []
        let (sut, loader) = makeSUT(actionHandler: {
            invokedActions.append($0)
            exp.fulfill()
        })

        sut.simulateAppear()
        loader.completeSubscription(with: anyNSError())
        sut.renderedError()?.simulateTap()
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(invokedActions, [.dismissed])
    }

    func test_historyTap_deliversHistoryTapAction() {
        var invokedActions: [PlantMonitorAction] = []
        let (sut, _) = makeSUT(actionHandler: { invokedActions.append($0) })

        sut.simulateHistoryTap()

        XCTAssertEqual(invokedActions, [.historyTap])
    }
}
