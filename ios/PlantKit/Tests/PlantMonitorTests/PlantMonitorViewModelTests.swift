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
        sut.loadedMood = { received.append($0) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 70, issues: [.thirsty]))

        XCTAssertEqual(received, [.thirsty])
    }

    func test_appear_deliversHappyMoodWithoutIssues() {
        let (sut, _, healthLoader) = makeSUT()
        var received: [PlantMood] = []
        sut.loadedMood = { received.append($0) }

        sut.appear()
        healthLoader.completeLoad(with: PlantHealth(score: 100, issues: []))

        XCTAssertEqual(received, [.happy])
    }

    func test_healthUpdate_loadsHealthAgain() {
        let (sut, _, healthLoader) = makeSUT()
        var received: [PlantMood] = []
        sut.loadedMood = { received.append($0) }

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
        sut.loadedMood = { moods.append($0) }
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
            actionHandler: { _ in }
        )
        var received: [PlantMood] = []
        sut?.loadedMood = { received.append($0) }

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

    func test_appear_doesNotDeliverAfterSUTIsReleased() {
        let loader = LoaderStub()
        var sut: PlantMonitorViewModel? = PlantMonitorViewModel(loader: loader, healthLoader: HealthLoaderStub(), actionHandler: { _ in })
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
    ) -> (sut: PlantMonitorViewModel, loader: LoaderStub, healthLoader: HealthLoaderStub) {
        let loader = LoaderStub()
        let healthLoader = HealthLoaderStub()
        let sut = PlantMonitorViewModel(loader: loader, healthLoader: healthLoader, actionHandler: actionHandler)
        trackMemoryLeak(loader, file: file, line: line)
        trackMemoryLeak(healthLoader, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, loader, healthLoader)
    }
}
