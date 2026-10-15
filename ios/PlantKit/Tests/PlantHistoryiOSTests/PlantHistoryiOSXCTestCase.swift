import PlantHistory
import PlantHistoryiOS
import PlantShared
import XCTest

@MainActor
class PlantHistoryiOSXCTestCase: XCTestCase {
    func makeSUT(
        haptics: HapticsSpy = HapticsSpy(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantHistoryView, loader: LoaderStub) {
        let loader = LoaderStub()
        let sut = PlantHistoryUIComposer.composed(with: loader, haptics: haptics)
        trackMemoryLeak(loader, file: file, line: line)
        trackMemoryLeak(haptics, file: file, line: line)
        return (sut, loader)
    }

    func anyNSError() -> NSError {
        NSError(domain: "any", code: 1)
    }

    func anyDate() -> Date {
        Date(timeIntervalSince1970: 1_767_254_400)
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
    final class HapticsSpy: PlantHapticsClient {
        private(set) var played: [PlantHaptic] = []
        func play(_ haptic: PlantHaptic) { played.append(haptic) }
        func clear() { played.removeAll() }
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

extension String {
    static func localised(key: String) -> String {
        NSLocalizedString(key, tableName: "PlantHistory", bundle: PlantHistoryBundle.bundle, comment: "")
    }
}
