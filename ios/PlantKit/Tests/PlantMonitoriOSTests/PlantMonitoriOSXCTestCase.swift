import PlantMonitor
import PlantMonitoriOS
import PlantShared
import XCTest

@MainActor
class PlantMonitoriOSXCTestCase: XCTestCase {
    func makeSUT(
        actionHandler: @escaping (PlantMonitorAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantMonitorView, loader: LoaderStub) {
        let loader = LoaderStub()
        let sut = PlantMonitorUIComposer.composed(with: loader, actionHandler: actionHandler)
        trackMemoryLeak(loader, file: file, line: line)
        return (sut, loader)
    }

    func anyNSError() -> NSError {
        NSError(domain: "any", code: 1)
    }

    func makeReading(
        moisture: Double? = 50,
        lux: Int? = 1_000,
        temperature: Double? = 23.5,
        humidity: Double? = 55.2,
        batteryMillivolts: Int? = nil,
        sequence: UInt32 = 42,
        receivedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> PlantReading {
        PlantReading(
            moisture: moisture,
            lux: lux,
            temperature: temperature,
            humidity: humidity,
            batteryMillivolts: batteryMillivolts,
            sequence: sequence,
            receivedAt: receivedAt
        )
    }

    func trackMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be deallocated. Potential memory leak", file: file, line: line)
        }
    }

    @MainActor
    final class LoaderStub: PlantReadingLoader {
        enum Message: Equatable {
            case loadReading
            case subscribeReadings
        }

        var messages: [Message] = []

        private var loadCompletions: [(PlantReadingLoader.Result) -> Void] = []
        func load(completion: @escaping (PlantReadingLoader.Result) -> Void) {
            messages.append(.loadReading)
            loadCompletions.append(completion)
        }

        private var subscriptions: [(PlantReadingLoader.Result) -> Void] = []
        func subscribe(update: @escaping (PlantReadingLoader.Result) -> Void) {
            messages.append(.subscribeReadings)
            subscriptions.append(update)
        }

        func completeSubscription(with reading: PlantReading, at index: Int = 0) {
            subscriptions[index](.success(reading))
        }

        func completeSubscription(with error: Error, at index: Int = 0) {
            subscriptions[index](.failure(error))
        }
    }
}

extension String {
    static func localised(key: String) -> String {
        NSLocalizedString(key, tableName: "PlantMonitor", bundle: PlantMonitorBundle.bundle, comment: "")
    }
}
