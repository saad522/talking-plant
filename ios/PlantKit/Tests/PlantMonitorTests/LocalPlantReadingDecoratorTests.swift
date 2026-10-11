import PlantMonitor
import PlantShared
import XCTest

@MainActor
final class LocalPlantReadingDecoratorTests: PlantMonitorXCTestCase {
    func test_init_doesNotMessageDecorateeOrStore() {
        let (_, decoratee, store) = makeSUT()

        XCTAssertEqual(decoratee.messages, [])
        XCTAssertEqual(store.messages, [])
    }

    // MARK: - Subscribe

    func test_subscribe_subscribesToDecoratee() {
        let (sut, decoratee, _) = makeSUT()

        sut.subscribe(update: { _ in })

        XCTAssertEqual(decoratee.messages, [.subscribeReadings])
    }

    func test_subscribe_forwardsReadingsUnchanged() throws {
        let (sut, decoratee, _) = makeSUT()
        let reading = makeReading(sequence: 1)
        var received: [PlantReading] = []
        sut.subscribe { received.append(try! $0.get()) }

        decoratee.completeSubscription(with: reading)

        XCTAssertEqual(received, [reading])
    }

    func test_subscribe_forwardsErrorsWithoutSaving() {
        let (sut, decoratee, store) = makeSUT()
        var received: [NSError] = []
        sut.subscribe { result in
            if case let .failure(error) = result { received.append(error as NSError) }
        }

        decoratee.completeSubscription(with: anyNSError())

        XCTAssertEqual(received, [anyNSError()])
        XCTAssertEqual(store.messages, [])
    }

    func test_subscribe_savesEverySuccessfulReading() {
        let (sut, decoratee, store) = makeSUT()
        let first = makeReading(sequence: 1)
        let second = makeReading(sequence: 2)
        sut.subscribe(update: { _ in })

        decoratee.completeSubscription(with: first)
        decoratee.completeSubscription(with: second)

        XCTAssertEqual(store.messages, [.insert(first), .insert(second)])
    }

    func test_subscribe_skipsReadingWithSameSequenceAsLastSaved() {
        let (sut, decoratee, store) = makeSUT()
        let first = makeReading(sequence: 1)
        let duplicate = makeReading(moisture: 10, sequence: 1, receivedAt: anyDate().addingTimeInterval(1))
        var forwarded = 0
        sut.subscribe { _ in forwarded += 1 }

        decoratee.completeSubscription(with: first)
        decoratee.completeSubscription(with: duplicate)

        XCTAssertEqual(store.messages, [.insert(first)])
        XCTAssertEqual(forwarded, 2, "Duplicates are still forwarded")
    }

    func test_subscribe_savesRepeatedSequenceWhenNotTheLastSaved() {
        let (sut, decoratee, store) = makeSUT()
        let first = makeReading(sequence: 1)
        let second = makeReading(sequence: 2)
        sut.subscribe(update: { _ in })

        decoratee.completeSubscription(with: first)
        decoratee.completeSubscription(with: second)
        decoratee.completeSubscription(with: first)

        XCTAssertEqual(store.messages, [.insert(first), .insert(second), .insert(first)])
    }

    func test_subscribe_forwardsReadingWhenStoreFails() {
        let (sut, decoratee, store) = makeSUT()
        let reading = makeReading(sequence: 1)
        var received: [PlantReading] = []
        sut.subscribe { received.append(try! $0.get()) }

        decoratee.completeSubscription(with: reading)
        store.completeInsertion(with: anyNSError())

        XCTAssertEqual(received, [reading])
    }

    func test_subscribe_retriesSameSequenceAfterFailedInsert() {
        let (sut, decoratee, store) = makeSUT()
        let reading = makeReading(sequence: 1)
        sut.subscribe(update: { _ in })

        decoratee.completeSubscription(with: reading)
        store.completeInsertion(with: anyNSError())
        decoratee.completeSubscription(with: reading)

        XCTAssertEqual(store.messages, [.insert(reading), .insert(reading)])
    }

    func test_subscribe_doesNotCreateMemoryLeaks() {
        let decoratee = LoaderStub()
        let store = StoreSpy()
        var sut: LocalPlantReadingDecorator? = LocalPlantReadingDecorator(decoratee: decoratee, store: store)
        weak let weakSUT = sut

        sut?.subscribe(update: { _ in })

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Load

    func test_load_loadsFromDecoratee() {
        let (sut, decoratee, _) = makeSUT()

        sut.load(completion: { _ in })

        XCTAssertEqual(decoratee.messages, [.loadReading])
    }

    func test_load_forwardsAndSavesReading() {
        let (sut, decoratee, store) = makeSUT()
        let reading = makeReading(sequence: 7)
        var received: PlantReading?
        sut.load { received = try? $0.get() }

        decoratee.completeLoad(with: reading)

        XCTAssertEqual(received, reading)
        XCTAssertEqual(store.messages, [.insert(reading)])
    }

    func test_load_forwardsErrorWithoutSaving() {
        let (sut, decoratee, store) = makeSUT()
        var received: NSError?
        sut.load { result in
            if case let .failure(error) = result { received = error as NSError }
        }

        decoratee.completeLoad(with: anyNSError())

        XCTAssertEqual(received, anyNSError())
        XCTAssertEqual(store.messages, [])
    }

    // MARK: - Private helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LocalPlantReadingDecorator, decoratee: LoaderStub, store: StoreSpy) {
        let decoratee = LoaderStub()
        let store = StoreSpy()
        let sut = LocalPlantReadingDecorator(decoratee: decoratee, store: store)
        trackMemoryLeak(decoratee, file: file, line: line)
        trackMemoryLeak(store, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, decoratee, store)
    }
}
