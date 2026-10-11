import PlantMonitor
import PlantMonitoriOS
import PlantShared
import SwiftUI
import XCTest

@MainActor
class PlantMonitoriOSXCTestCase: XCTestCase {
    func makeSUT(
        actionHandler: @escaping (PlantMonitorAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantMonitorView<FaceStub>, loader: LoaderStub, healthLoader: HealthLoaderStub) {
        let loader = LoaderStub()
        let healthLoader = HealthLoaderStub()
        let sut = PlantMonitorUIComposer.composed(
            with: loader,
            healthLoader: healthLoader,
            face: { FaceStub(mood: $0) },
            actionHandler: actionHandler
        )
        trackMemoryLeak(loader, file: file, line: line)
        trackMemoryLeak(healthLoader, file: file, line: line)
        return (sut, loader, healthLoader)
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
    final class HealthLoaderStub: PlantHealthLoader {
        enum Message: Equatable {
            case loadHealth
            case subscribeHealth
        }

        var messages: [Message] = []

        private var loadCompletions: [(PlantHealthLoader.Result) -> Void] = []
        func load(completion: @escaping (PlantHealthLoader.Result) -> Void) {
            messages.append(.loadHealth)
            loadCompletions.append(completion)
        }

        func completeLoad(with health: PlantHealth, at index: Int = 0) {
            loadCompletions[index](.success(health))
        }

        func completeLoad(with error: Error, at index: Int = 0) {
            loadCompletions[index](.failure(error))
        }

        private var subscriptions: [() -> Void] = []
        func subscribe(update: @escaping () -> Void) {
            messages.append(.subscribeHealth)
            subscriptions.append(update)
        }

        func simulateUpdate(at index: Int = 0) {
            subscriptions[index]()
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

struct FaceStub: View, Equatable {
    let mood: PlantMood

    var body: some View {
        Text("face")
    }
}

extension String {
    static func localised(key: String) -> String {
        NSLocalizedString(key, tableName: "PlantMonitor", bundle: PlantMonitorBundle.bundle, comment: "")
    }
}
