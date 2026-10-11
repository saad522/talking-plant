import PlantShared
import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorViewModelTests: PlantMonitorXCTestCase {
    func test_init_doesNotMessageLoader() {
        let (_, loader) = makeSUT()

        XCTAssertEqual(loader.messages, [])
    }

    func test_init_hasLocalisedHistoryLabel() {
        let (sut, _) = makeSUT()

        XCTAssertEqual(sut.historyLabel, String.localised(key: "plant.monitor.history.label"))
    }

    func test_appear_subscribesToReadingsOnce() {
        let (sut, loader) = makeSUT()

        sut.appear()
        sut.appear()

        XCTAssertEqual(loader.messages, [.subscribeReadings])
    }

    func test_appear_deliversEveryReadingFromLoader() {
        let (sut, loader) = makeSUT()
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
        let (sut, loader) = makeSUT()
        var received: [NSError] = []
        sut.loadedError = { received.append($0 as NSError) }

        sut.appear()
        loader.completeSubscription(with: anyNSError())

        XCTAssertEqual(received, [anyNSError()])
    }

    func test_historyTap_deliversHistoryTapAction() {
        var actions: [PlantMonitorAction] = []
        let (sut, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.historyTap()

        XCTAssertEqual(actions, [.historyTap])
    }

    func test_appear_doesNotDeliverAfterSUTIsReleased() {
        let loader = LoaderStub()
        var sut: PlantMonitorViewModel? = PlantMonitorViewModel(loader: loader, actionHandler: { _ in })
        var received: [PlantReading] = []
        sut?.loadedReading = { received.append($0) }

        sut?.appear()
        sut = nil
        loader.completeSubscription(with: makeReading())

        XCTAssertEqual(received, [])
    }

    // MARK: - Private helpers

    private func makeSUT(
        actionHandler: @escaping (PlantMonitorAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantMonitorViewModel, loader: LoaderStub) {
        let loader = LoaderStub()
        let sut = PlantMonitorViewModel(loader: loader, actionHandler: actionHandler)
        trackMemoryLeak(loader, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, loader)
    }
}
