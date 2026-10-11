import PlantHistory
import PlantShared
import XCTest

@MainActor
final class LocalPlantHistoryLoaderTests: PlantHistoryXCTestCase {
    func test_init_doesNotMessageStore() {
        let (_, store) = makeSUT()

        XCTAssertEqual(store.messages, [])
    }

    func test_load_retrievesRangeEndingNow() {
        let now = anyDate()
        let (sut, store) = makeSUT(currentDate: now)

        sut.load(.day) { _ in }
        sut.load(.week) { _ in }

        XCTAssertEqual(store.messages, [
            .retrieve(from: now.addingTimeInterval(-24 * 3_600), to: now),
            .retrieve(from: now.addingTimeInterval(-7 * 24 * 3_600), to: now),
        ])
    }

    func test_load_readsCurrentDateAtLoadTime() {
        var now = anyDate()
        let store = StoreSpy()
        let sut = LocalPlantHistoryLoader(store: store, currentDate: { now })

        now = anyDate().addingTimeInterval(3_600)
        sut.load(.day) { _ in }

        XCTAssertEqual(store.messages, [.retrieve(from: anyDate().addingTimeInterval(3_600 - 24 * 3_600), to: now)])
    }

    func test_load_deliversRetrievalErrorOnStoreFailure() {
        let (sut, store) = makeSUT()

        let result = load(.day, from: sut, when: { store.completeRetrieval(with: anyNSError()) })

        XCTAssertThrowsError(try result?.get()) { error in
            XCTAssertEqual(error as? LocalPlantHistoryLoader.Error, .retrieval)
        }
    }

    func test_load_deliversNoSamplesOnEmptyStore() throws {
        let (sut, store) = makeSUT()

        let result = load(.day, from: sut, when: { store.completeRetrieval(with: []) })

        XCTAssertEqual(try XCTUnwrap(result).get(), [])
    }

    func test_load_deliversSamplesDownsampledForRange() throws {
        let (sut, store) = makeSUT()
        let readings = [
            makeReading(moisture: 40, receivedAt: anyDate()),
            makeReading(moisture: 60, receivedAt: anyDate().addingTimeInterval(20 * 60)),
            makeReading(moisture: 80, receivedAt: anyDate().addingTimeInterval(70 * 60)),
        ]

        let day = load(.day, from: sut, when: { store.completeRetrieval(with: readings, at: 0) })
        let week = load(.week, from: sut, when: { store.completeRetrieval(with: readings, at: 1) })

        XCTAssertEqual(try XCTUnwrap(day).get().map(\.moisture), [40, 60, 80])
        XCTAssertEqual(try XCTUnwrap(week).get().map(\.moisture), [50, 80])
    }

    func test_subscribe_forwardsStoreInsertions() {
        let (sut, store) = makeSUT()
        var updates = 0
        sut.subscribe { updates += 1 }

        store.simulateInsertion()
        store.simulateInsertion()

        XCTAssertEqual(store.messages, [.subscribe])
        XCTAssertEqual(updates, 2)
    }

    func test_load_doesNotCreateMemoryLeaks() {
        let store = StoreSpy()
        var sut: LocalPlantHistoryLoader? = LocalPlantHistoryLoader(store: store)
        weak let weakSUT = sut

        sut?.load(.day) { _ in }

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(
        currentDate: Date = Date(timeIntervalSince1970: 1_767_254_400),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LocalPlantHistoryLoader, store: StoreSpy) {
        let store = StoreSpy()
        let sut = LocalPlantHistoryLoader(store: store, currentDate: { currentDate })
        trackMemoryLeak(store, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, store)
    }

    private func load(
        _ range: PlantHistoryRange,
        from sut: LocalPlantHistoryLoader,
        when action: () -> Void
    ) -> PlantHistoryLoader.Result? {
        var received: PlantHistoryLoader.Result?
        sut.load(range) { received = $0 }
        action()
        return received
    }
}
