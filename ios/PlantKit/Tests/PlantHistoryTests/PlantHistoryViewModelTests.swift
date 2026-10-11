import XCTest
@testable import PlantHistory

@MainActor
final class PlantHistoryViewModelTests: PlantHistoryXCTestCase {
    func test_init_doesNotMessageLoader() {
        let (_, loader) = makeSUT()

        XCTAssertEqual(loader.messages, [])
    }

    func test_init_hasLocalisedTitles() {
        let (sut, _) = makeSUT()

        XCTAssertEqual(sut.title, String.localised(key: "plant.history.title"))
        XCTAssertEqual(sut.ranges, [.day, .week])
        XCTAssertEqual(sut.title(for: .day), String.localised(key: "plant.history.range.day"))
        XCTAssertEqual(sut.title(for: .week), String.localised(key: "plant.history.range.week"))
    }

    func test_appear_loadsDayAndSubscribesOnce() {
        let (sut, loader) = makeSUT()

        sut.appear()
        sut.appear()

        XCTAssertEqual(loader.messages, [.load(.day), .subscribe])
    }

    func test_appear_deliversSelectedRange() {
        let (sut, _) = makeSUT()
        var ranges: [PlantHistoryRange] = []
        sut.loadedRange = { ranges.append($0) }

        sut.appear()

        XCTAssertEqual(ranges, [.day])
    }

    func test_appear_deliversSamplesOnSuccess() {
        let (sut, loader) = makeSUT()
        let samples = [makeSample(moisture: 40), makeSample(date: anyDate().addingTimeInterval(600), moisture: 42)]
        var received: [[PlantHistorySample]] = []
        sut.loadedSamples = { received.append($0) }

        sut.appear()
        loader.completeLoad(with: samples)

        XCTAssertEqual(received, [samples])
    }

    func test_appear_deliversEmptyDescriptionOnNoSamples() {
        let (sut, loader) = makeSUT()
        var received: [String] = []
        var samples = 0
        sut.loadedEmpty = { received.append($0) }
        sut.loadedSamples = { _ in samples += 1 }

        sut.appear()
        loader.completeLoad(with: [])

        XCTAssertEqual(received, [String.localised(key: "plant.history.empty.description")])
        XCTAssertEqual(samples, 0)
    }

    func test_appear_deliversErrorDescriptionOnFailure() {
        let (sut, loader) = makeSUT()
        var received: [String] = []
        sut.loadedError = { received.append($0) }

        sut.appear()
        loader.completeLoad(with: anyNSError())

        XCTAssertEqual(received, [String.localised(key: "plant.history.error.description")])
    }

    func test_historyChange_reloadsSelectedRange() {
        let (sut, loader) = makeSUT()
        sut.appear()
        sut.select(.week)

        loader.simulateHistoryChange()

        XCTAssertEqual(loader.messages, [.load(.day), .subscribe, .load(.week), .load(.week)])
    }

    func test_select_loadsNewRangeAndDeliversIt() {
        let (sut, loader) = makeSUT()
        var ranges: [PlantHistoryRange] = []
        sut.loadedRange = { ranges.append($0) }
        sut.appear()

        sut.select(.week)

        XCTAssertEqual(sut.selectedRange, .week)
        XCTAssertEqual(ranges, [.day, .week])
        XCTAssertEqual(loader.messages, [.load(.day), .subscribe, .load(.week)])
    }

    func test_select_doesNotReloadSameRange() {
        let (sut, loader) = makeSUT()
        sut.appear()

        sut.select(.day)

        XCTAssertEqual(loader.messages, [.load(.day), .subscribe])
    }

    func test_select_ignoresResultForPreviousRange() {
        let (sut, loader) = makeSUT()
        let weekSamples = [makeSample(moisture: 70)]
        var received: [[PlantHistorySample]] = []
        sut.loadedSamples = { received.append($0) }
        sut.appear()
        sut.select(.week)

        loader.completeLoad(with: [makeSample(moisture: 10)], at: 0)
        loader.completeLoad(with: weekSamples, at: 1)

        XCTAssertEqual(received, [weekSamples])
    }

    func test_appear_doesNotDeliverAfterSUTIsReleased() {
        let loader = LoaderStub()
        var sut: PlantHistoryViewModel? = PlantHistoryViewModel(loader: loader)
        var received = 0
        sut?.loadedSamples = { _ in received += 1 }

        sut?.appear()
        sut = nil
        loader.completeLoad(with: [makeSample()])
        loader.simulateHistoryChange()

        XCTAssertEqual(received, 0)
        XCTAssertEqual(loader.messages, [.load(.day), .subscribe])
    }

    // MARK: - Private helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantHistoryViewModel, loader: LoaderStub) {
        let loader = LoaderStub()
        let sut = PlantHistoryViewModel(loader: loader)
        trackMemoryLeak(loader, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, loader)
    }
}
