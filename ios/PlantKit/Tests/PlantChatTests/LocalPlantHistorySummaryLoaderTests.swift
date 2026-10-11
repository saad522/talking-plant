import PlantShared
import XCTest
@testable import PlantChat

@MainActor
final class LocalPlantHistorySummaryLoaderTests: PlantChatXCTestCase {
    func test_init_doesNotMessageStore() {
        let (_, store) = makeSUT()

        XCTAssertEqual(store.messages, [])
    }

    func test_load_retrievesWindowOfEachPeriod() {
        let now = anyDate()
        let (sut, store) = makeSUT(currentDate: now)

        sut.load(.day) { _ in }
        sut.load(.week) { _ in }

        XCTAssertEqual(store.messages, [
            .retrieve(from: now.addingTimeInterval(-86_400), to: now),
            .retrieve(from: now.addingTimeInterval(-7 * 86_400), to: now)
        ])
    }

    func test_load_deliversMinimumAverageAndMaximumOfEachSensor() {
        let (sut, store) = makeSUT()
        let readings = [
            makeReading(moisture: 20, lux: 100, temperature: 18, humidity: 40),
            makeReading(moisture: 40, lux: 300, temperature: 22, humidity: 60),
            makeReading(moisture: 30, lux: 200, temperature: 20, humidity: 50)
        ]

        expect(sut, .week, toDeliver: .success(PlantHistorySummary(
            period: .week,
            readingCount: 3,
            moisture: .init(minimum: 20, average: 30, maximum: 40),
            lux: .init(minimum: 100, average: 200, maximum: 300),
            temperature: .init(minimum: 18, average: 20, maximum: 22),
            humidity: .init(minimum: 40, average: 50, maximum: 60)
        )), when: { store.completeRetrieval(with: readings) })
    }

    func test_load_ignoresNilValues() {
        let (sut, store) = makeSUT()
        let readings = [
            makeReading(moisture: 20, lux: nil, temperature: nil, humidity: nil),
            makeReading(moisture: nil, lux: nil, temperature: 22, humidity: nil),
            makeReading(moisture: 40, lux: nil, temperature: nil, humidity: nil)
        ]

        expect(sut, .day, toDeliver: .success(PlantHistorySummary(
            period: .day,
            readingCount: 3,
            moisture: .init(minimum: 20, average: 30, maximum: 40),
            lux: nil,
            temperature: .init(minimum: 22, average: 22, maximum: 22),
            humidity: nil
        )), when: { store.completeRetrieval(with: readings) })
    }

    func test_load_deliversEmptySummaryForEmptyHistory() {
        let (sut, store) = makeSUT()

        expect(sut, .day, toDeliver: .success(PlantHistorySummary(
            period: .day,
            readingCount: 0,
            moisture: nil,
            lux: nil,
            temperature: nil,
            humidity: nil
        )), when: { store.completeRetrieval(with: []) })
    }

    func test_load_deliversRetrievalErrorOnStoreFailure() {
        let (sut, store) = makeSUT()

        expect(sut, .day, toDeliver: .failure(LocalPlantHistorySummaryLoader.Error.retrieval), when: {
            store.completeRetrieval(with: anyNSError())
        })
    }

    func test_load_doesNotCreateMemoryLeaks() {
        let store = StoreSpy()
        var sut: LocalPlantHistorySummaryLoader? = LocalPlantHistorySummaryLoader(store: store)
        weak var weakSUT = sut

        sut?.load(.day) { _ in }
        sut = nil

        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(
        currentDate: Date? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LocalPlantHistorySummaryLoader, store: StoreSpy) {
        let store = StoreSpy()
        let now = currentDate ?? anyDate()
        let sut = LocalPlantHistorySummaryLoader(store: store, currentDate: { now })
        trackMemoryLeak(store, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, store)
    }

    private func expect(
        _ sut: LocalPlantHistorySummaryLoader,
        _ period: PlantHistorySummary.Period,
        toDeliver expected: PlantHistorySummaryLoader.Result,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var received: [PlantHistorySummaryLoader.Result] = []
        sut.load(period) { received.append($0) }

        action()

        guard received.count == 1 else {
            return XCTFail("Expected one result, got \(received.count)", file: file, line: line)
        }
        switch (expected, received[0]) {
        case let (.success(expected), .success(received)):
            XCTAssertEqual(expected, received, file: file, line: line)
        case let (.failure(expected as LocalPlantHistorySummaryLoader.Error), .failure(received as LocalPlantHistorySummaryLoader.Error)):
            XCTAssertEqual(expected, received, file: file, line: line)
        default:
            XCTFail("Expected \(expected), got \(received[0]) instead", file: file, line: line)
        }
    }
}
