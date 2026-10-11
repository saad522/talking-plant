import PlantHistory
import PlantShared
import XCTest

@MainActor
class PlantHistoryXCTestCase: XCTestCase {
    func anyNSError() -> NSError {
        NSError(domain: "any", code: 1)
    }

    /// 2026-01-01 08:00 UTC, a whole multiple of both bucket sizes.
    func anyDate() -> Date {
        Date(timeIntervalSince1970: 1_767_254_400)
    }

    func makeReading(
        moisture: Double? = 50,
        lux: Int? = 1_000,
        temperature: Double? = 23.5,
        humidity: Double? = 55.2,
        sequence: UInt32 = 42,
        receivedAt: Date = Date(timeIntervalSince1970: 1_767_254_400)
    ) -> PlantReading {
        PlantReading(
            moisture: moisture,
            lux: lux,
            temperature: temperature,
            humidity: humidity,
            batteryMillivolts: nil,
            sequence: sequence,
            receivedAt: receivedAt
        )
    }

    func makeSample(
        date: Date = Date(timeIntervalSince1970: 1_767_254_400),
        moisture: Double? = 50,
        lux: Double? = 1_000,
        temperature: Double? = 23.5,
        humidity: Double? = 55.2
    ) -> PlantHistorySample {
        PlantHistorySample(date: date, moisture: moisture, lux: lux, temperature: temperature, humidity: humidity)
    }

    func trackMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be deallocated. Potential memory leak", file: file, line: line)
        }
    }

    @MainActor
    final class StoreSpy: PlantReadingStore {
        enum Message: Equatable {
            case insert(PlantReading)
            case retrieve(from: Date, to: Date)
            case subscribe
        }

        var messages: [Message] = []

        func insert(_ reading: PlantReading, completion: @escaping (PlantReadingStore.InsertionResult) -> Void) {
            messages.append(.insert(reading))
        }

        private var retrievalCompletions: [(PlantReadingStore.RetrievalResult) -> Void] = []
        func retrieve(from start: Date, to end: Date, completion: @escaping (PlantReadingStore.RetrievalResult) -> Void) {
            messages.append(.retrieve(from: start, to: end))
            retrievalCompletions.append(completion)
        }

        func completeRetrieval(with readings: [PlantReading], at index: Int = 0) {
            retrievalCompletions[index](.success(readings))
        }

        func completeRetrieval(with error: Error, at index: Int = 0) {
            retrievalCompletions[index](.failure(error))
        }

        private var subscriptions: [() -> Void] = []
        func subscribe(update: @escaping () -> Void) {
            messages.append(.subscribe)
            subscriptions.append(update)
        }

        func simulateInsertion(at index: Int = 0) {
            subscriptions[index]()
        }
    }

    @MainActor
    final class LoaderStub: PlantHistoryLoader {
        enum Message: Equatable {
            case load(PlantHistoryRange)
            case subscribe
        }

        var messages: [Message] = []

        private var loadCompletions: [(PlantHistoryLoader.Result) -> Void] = []
        func load(_ range: PlantHistoryRange, completion: @escaping (PlantHistoryLoader.Result) -> Void) {
            messages.append(.load(range))
            loadCompletions.append(completion)
        }

        func completeLoad(with samples: [PlantHistorySample], at index: Int = 0) {
            loadCompletions[index](.success(samples))
        }

        func completeLoad(with error: Error, at index: Int = 0) {
            loadCompletions[index](.failure(error))
        }

        private var subscriptions: [() -> Void] = []
        func subscribe(update: @escaping () -> Void) {
            messages.append(.subscribe)
            subscriptions.append(update)
        }

        func simulateHistoryChange(at index: Int = 0) {
            subscriptions[index]()
        }
    }
}
