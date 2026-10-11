import PlantShared
import XCTest
@testable import PlantMonitor

@MainActor
final class LocalPlantHealthLoaderTests: PlantMonitorXCTestCase {
    func test_init_doesNotMessageStoreOrSchedule() {
        let (_, store, schedule) = makeSUT()

        XCTAssertEqual(store.messages, [])
        XCTAssertEqual(schedule.intervals, [])
    }

    func test_load_retrievesHistoryWindowEndingNow() {
        let now = anyDate()
        let (sut, store, _) = makeSUT(currentDate: now, profile: .houseplant)

        sut.load { _ in }

        XCTAssertEqual(store.messages, [.retrieve(from: now.addingTimeInterval(-PlantProfile.houseplant.historyWindow), to: now)])
    }

    func test_load_readsCurrentDateAtLoadTime() {
        var now = anyDate()
        let store = StoreSpy()
        let sut = LocalPlantHealthLoader(
            store: store,
            profile: .houseplant,
            currentDate: { now },
            recheckInterval: 60,
            schedule: ScheduleSpy().schedule
        )

        now = anyDate().addingTimeInterval(3_600)
        sut.load { _ in }

        XCTAssertEqual(store.messages, [
            .retrieve(from: now.addingTimeInterval(-PlantProfile.houseplant.historyWindow), to: now)
        ])
    }

    func test_load_deliversRetrievalErrorOnStoreFailure() {
        let (sut, store, _) = makeSUT()

        let result = load(from: sut, when: { store.completeRetrieval(with: anyNSError()) })

        XCTAssertThrowsError(try result?.get()) { error in
            XCTAssertEqual(error as? LocalPlantHealthLoader.Error, .retrieval)
        }
    }

    func test_load_deliversOfflineHealthOnEmptyStore() throws {
        let (sut, store, _) = makeSUT()

        let result = load(from: sut, when: { store.completeRetrieval(with: []) })

        XCTAssertEqual(try XCTUnwrap(result).get(), PlantHealth(score: 100, issues: [.offline]))
    }

    func test_load_deliversHealthEvaluatedFromStoredReadings() throws {
        let now = anyDate()
        let (sut, store, _) = makeSUT(currentDate: now)
        let readings = [makeReading(moisture: 20, receivedAt: now.addingTimeInterval(-60))]

        let result = load(from: sut, when: { store.completeRetrieval(with: readings) })

        XCTAssertEqual(try XCTUnwrap(result).get(), PlantHealth(score: 70, issues: [.thirsty]))
    }

    func test_subscribe_forwardsStoreInsertions() {
        let (sut, store, _) = makeSUT()
        var updates = 0
        sut.subscribe { updates += 1 }

        store.simulateInsertion()
        store.simulateInsertion()

        XCTAssertEqual(store.messages, [.subscribe])
        XCTAssertEqual(updates, 2)
    }

    func test_subscribe_schedulesRechecksAtInterval() {
        let (sut, _, schedule) = makeSUT(recheckInterval: 90)
        var updates = 0
        sut.subscribe { updates += 1 }

        XCTAssertEqual(schedule.intervals, [90])
        XCTAssertTrue(schedule.fire())
        XCTAssertTrue(schedule.fire())
        XCTAssertEqual(updates, 2)
    }

    func test_load_doesNotCreateMemoryLeaks() {
        let store = StoreSpy()
        var sut: LocalPlantHealthLoader? = LocalPlantHealthLoader(
            store: store,
            profile: .houseplant,
            recheckInterval: 60,
            schedule: ScheduleSpy().schedule
        )
        weak let weakSUT = sut

        sut?.load { _ in }
        sut?.subscribe { }

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(
        currentDate: Date = Date(timeIntervalSince1970: 1_000_000),
        profile: PlantProfile = .houseplant,
        recheckInterval: TimeInterval = 60,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LocalPlantHealthLoader, store: StoreSpy, schedule: ScheduleSpy) {
        let store = StoreSpy()
        let schedule = ScheduleSpy()
        let sut = LocalPlantHealthLoader(
            store: store,
            profile: profile,
            currentDate: { currentDate },
            recheckInterval: recheckInterval,
            schedule: schedule.schedule
        )
        trackMemoryLeak(store, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, store, schedule)
    }

    private func load(from sut: LocalPlantHealthLoader, when action: () -> Void) -> PlantHealthLoader.Result? {
        var received: PlantHealthLoader.Result?
        sut.load { received = $0 }
        action()
        return received
    }
}
