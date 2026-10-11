import PlantHistory
import PlantHistoryiOS
import XCTest

@MainActor
final class PlantHistoryUIITests: PlantHistoryiOSXCTestCase {
    func test_init_doesNotMessageLoader() {
        let (_, loader) = makeSUT()

        XCTAssertEqual(loader.messages, [])
    }

    func test_init_displaysLoadingWithoutChartsOrMessage() {
        let (sut, _) = makeSUT()

        XCTAssertTrue(sut.isLoading)
        XCTAssertEqual(sut.renderedCharts().count, 0)
        XCTAssertNil(sut.renderedMessage())
    }

    func test_init_rendersRangePickerWithDaySelected() {
        let (sut, _) = makeSUT()

        XCTAssertEqual(sut.selectedRange, .day)
        XCTAssertEqual(sut.rangeTitles, [
            String.localised(key: "plant.history.range.day"),
            String.localised(key: "plant.history.range.week"),
        ])
    }

    func test_appear_loadsDayAndSubscribesOnce() {
        let (sut, loader) = makeSUT()

        sut.simulateAppear()
        sut.simulateAppear()

        XCTAssertEqual(loader.messages, [.load(.day), .subscribe])
    }

    func test_appear_rendersChartsWithLatestValuesOnSamples() {
        let (sut, loader) = makeSUT()
        let samples = [
            makeSample(date: anyDate(), moisture: 40, lux: 800, temperature: 20, humidity: 50),
            makeSample(date: anyDate().addingTimeInterval(600), moisture: 42, lux: 1_200, temperature: 21.5, humidity: 60),
        ]

        sut.simulateAppear()
        loader.completeLoad(with: samples)

        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.renderedCharts().map(\.title), [
            String.localised(key: "plant.history.moisture.title"),
            String.localised(key: "plant.history.light.title"),
            String.localised(key: "plant.history.temperature.title"),
            String.localised(key: "plant.history.humidity.title"),
        ])
        XCTAssertEqual(sut.renderedCharts().map(\.latestValue), ["42%", "1,200 lx", "21.5 °C", "60%"])
    }

    func test_appear_displaysEmptyMessageWithoutChartsOnNoSamples() {
        let (sut, loader) = makeSUT()

        sut.simulateAppear()
        loader.completeLoad(with: [])

        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.renderedCharts().count, 0)
        XCTAssertEqual(sut.renderedMessage()?.text, String.localised(key: "plant.history.empty.description"))
    }

    func test_appear_displaysErrorMessageOnFailure() {
        let (sut, loader) = makeSUT()

        sut.simulateAppear()
        loader.completeLoad(with: anyNSError())

        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.renderedMessage()?.text, String.localised(key: "plant.history.error.description"))
    }

    func test_historyChange_reloadsAndRendersNewSamples() {
        let (sut, loader) = makeSUT()
        sut.simulateAppear()
        loader.completeLoad(with: [makeSample(moisture: 40)])

        loader.simulateHistoryChange()
        loader.completeLoad(with: [makeSample(moisture: 40), makeSample(date: anyDate().addingTimeInterval(600), moisture: 38)], at: 1)

        XCTAssertEqual(loader.messages, [.load(.day), .subscribe, .load(.day)])
        XCTAssertEqual(sut.renderedCharts().first?.latestValue, "38%")
    }

    func test_historyChange_hidesMessageWhenSamplesArrive() {
        let (sut, loader) = makeSUT()
        sut.simulateAppear()
        loader.completeLoad(with: [])

        loader.simulateHistoryChange()
        loader.completeLoad(with: [makeSample()], at: 1)

        XCTAssertNil(sut.renderedMessage())
        XCTAssertEqual(sut.renderedCharts().count, 4)
    }

    func test_selectingRange_loadsAndSelectsWeek() {
        let (sut, loader) = makeSUT()
        sut.simulateAppear()

        sut.simulateSelecting(.week)

        XCTAssertEqual(sut.selectedRange, .week)
        XCTAssertEqual(loader.messages, [.load(.day), .subscribe, .load(.week)])
    }

    func test_selectingRange_rendersOnlyResultForSelectedRange() {
        let (sut, loader) = makeSUT()
        sut.simulateAppear()
        sut.simulateSelecting(.week)

        loader.completeLoad(with: [makeSample(moisture: 70)], at: 1)
        loader.completeLoad(with: [makeSample(moisture: 10)], at: 0)

        XCTAssertEqual(sut.renderedCharts().first?.latestValue, "70%")
    }
}
