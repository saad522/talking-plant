import PlantShared
import XCTest

@MainActor
final class SwiftDataPlantReadingStoreTests: PlantSharedXCTestCase {
    func test_retrieve_deliversEmptyOnEmptyStore() throws {
        let sut = try makeSUT()

        XCTAssertEqual(try retrieve(from: sut), [])
    }

    func test_retrieve_deliversReadingsInRangeOldestFirst() throws {
        let sut = try makeSUT()
        let first = makeReading(sequence: 1, receivedAt: morningDate())
        let second = makeReading(sequence: 2, receivedAt: morningDate().addingTimeInterval(60))
        let third = makeReading(sequence: 3, receivedAt: morningDate().addingTimeInterval(120))
        try insert([third, first, second], into: sut)

        XCTAssertEqual(try retrieve(from: sut), [first, second, third])
    }

    func test_retrieve_includesRangeBoundariesAndExcludesOutside() throws {
        let sut = try makeSUT()
        let readings = (0..<5).map { makeReading(sequence: UInt32($0), receivedAt: morningDate().addingTimeInterval(Double($0) * 60)) }
        try insert(readings, into: sut)

        let received = try retrieve(from: sut, from: readings[1].receivedAt, to: readings[3].receivedAt)

        XCTAssertEqual(received, Array(readings[1...3]))
    }

    func test_insert_preservesEveryField() throws {
        let sut = try makeSUT()
        let full = makeReading(moisture: 12.5, lux: 65_535, temperature: -10.5, humidity: 99.9, batteryMillivolts: 4_200, sequence: .max)
        let empty = makeReading(moisture: nil, lux: nil, temperature: nil, humidity: nil, batteryMillivolts: nil, sequence: 0, receivedAt: morningDate().addingTimeInterval(1))
        try insert([full, empty], into: sut)

        XCTAssertEqual(try retrieve(from: sut), [full, empty])
    }

    func test_insert_deletesReadingsOlderThanRetentionFromNewestReading() throws {
        let sut = try makeSUT(retention: 3_600)
        let old = makeReading(sequence: 1, receivedAt: morningDate())
        let edge = makeReading(sequence: 2, receivedAt: morningDate().addingTimeInterval(1_800))
        let newest = makeReading(sequence: 3, receivedAt: morningDate().addingTimeInterval(1_800 + 3_600))
        try insert([old, edge], into: sut)

        try insert([newest], into: sut)

        XCTAssertEqual(try retrieve(from: sut), [edge, newest])
    }

    func test_insert_keepsThirtyDaysByDefault() throws {
        let sut = try makeSUT(retention: SwiftDataPlantReadingStore.defaultRetention)
        let thirtyDays: TimeInterval = 30 * 24 * 3_600
        let tooOld = makeReading(sequence: 1, receivedAt: morningDate().addingTimeInterval(-thirtyDays - 1))
        let kept = makeReading(sequence: 2, receivedAt: morningDate().addingTimeInterval(-thirtyDays))
        let newest = makeReading(sequence: 3, receivedAt: morningDate())

        try insert([tooOld, kept, newest], into: sut)

        XCTAssertEqual(try retrieve(from: sut), [kept, newest])
    }

    func test_insert_notifiesEverySubscriberAfterEachInsert() throws {
        let sut = try makeSUT()
        var first = 0
        var second = 0
        sut.subscribe { first += 1 }
        sut.subscribe { second += 1 }

        try insert([makeReading(sequence: 1), makeReading(sequence: 2)], into: sut)

        XCTAssertEqual(first, 2)
        XCTAssertEqual(second, 2)
    }

    func test_insert_doesNotNotifyBeforeInsert() throws {
        let sut = try makeSUT()
        var notified = 0

        sut.subscribe { notified += 1 }

        XCTAssertEqual(notified, 0)
    }

    func test_storeFile_keepsReadingsAcrossInstances() throws {
        let url = try makeTemporaryStoreURL()
        let reading = makeReading()
        try insert([reading], into: SwiftDataPlantReadingStore(storeURL: url))

        let relaunched = try SwiftDataPlantReadingStore(storeURL: url)

        XCTAssertEqual(try retrieve(from: relaunched), [reading])
    }

    func test_inMemoryStores_doNotShareReadings() throws {
        let first = try makeSUT()
        let second = try makeSUT()

        try insert([makeReading()], into: first)

        XCTAssertEqual(try retrieve(from: second), [])
    }

    func test_deleteAll_removesEveryReading() throws {
        let sut = try makeSUT()
        try insert([makeReading(sequence: 1), makeReading(sequence: 2, receivedAt: morningDate().addingTimeInterval(60))], into: sut)

        let error = deleteAll(from: sut)

        XCTAssertNil(error)
        XCTAssertEqual(try retrieve(from: sut), [])
    }

    func test_deleteAll_onEmptyStoreSucceeds() throws {
        let sut = try makeSUT()

        XCTAssertNil(deleteAll(from: sut))
        XCTAssertEqual(try retrieve(from: sut), [])
    }

    func test_deleteAll_allowsInsertingAfterwards() throws {
        let sut = try makeSUT()
        let reading = makeReading(sequence: 9)
        try insert([makeReading(sequence: 1)], into: sut)
        _ = deleteAll(from: sut)

        try insert([reading], into: sut)

        XCTAssertEqual(try retrieve(from: sut), [reading])
    }

    func test_deleteAll_notifiesSubscribers() throws {
        let sut = try makeSUT()
        var updates = 0
        sut.subscribe { updates += 1 }

        _ = deleteAll(from: sut)

        XCTAssertEqual(updates, 1)
    }

    // MARK: - Private helpers

    private func makeSUT(
        retention: TimeInterval = SwiftDataPlantReadingStore.defaultRetention,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> SwiftDataPlantReadingStore {
        let sut = try SwiftDataPlantReadingStore(storeURL: nil, retention: retention)
        trackMemoryLeak(sut, file: file, line: line)
        return sut
    }

    private func insert(_ readings: [PlantReading], into sut: SwiftDataPlantReadingStore) throws {
        for reading in readings {
            var insertionError: Error?
            sut.insert(reading) { insertionError = $0 }
            if let insertionError { throw insertionError }
        }
    }

    private func deleteAll(from sut: SwiftDataPlantReadingStore) -> Error? {
        var deletionError: Error?
        sut.deleteAll { deletionError = $0 }
        return deletionError
    }

    private func retrieve(
        from sut: SwiftDataPlantReadingStore,
        from start: Date = .distantPast,
        to end: Date = .distantFuture
    ) throws -> [PlantReading] {
        var received: PlantReadingStore.RetrievalResult?
        sut.retrieve(from: start, to: end) { received = $0 }
        return try XCTUnwrap(received).get()
    }

    private func makeTemporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("PlantHistory.store")
    }
}
