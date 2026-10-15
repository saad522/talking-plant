import PlantMonitor
import PlantMonitoriOS
import PlantShared
import SwiftUI
import XCTest

@MainActor
class PlantMonitoriOSXCTestCase: XCTestCase {
    func makeSUT(
        speechLoader: SpeechLoaderStub = SpeechLoaderStub(),
        lastScene: PlantMonitorScene = .day,
        haptics: HapticsSpy = HapticsSpy(),
        clock: ClockStub = ClockStub(at: Date(timeIntervalSince1970: 1_000)),
        scheduleSpy: ScheduleSpy = ScheduleSpy(),
        actionHandler: @escaping (PlantMonitorAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantMonitorView<FaceStub>, loader: LoaderStub, healthLoader: HealthLoaderStub, connectionLoader: ConnectionLoaderStub) {
        let loader = LoaderStub()
        let healthLoader = HealthLoaderStub()
        let connectionLoader = ConnectionLoaderStub()
        let sut = PlantMonitorUIComposer.composed(
            with: loader,
            healthLoader: healthLoader,
            connectionLoader: connectionLoader,
            speechLoader: speechLoader,
            plantName: "Sprout",
            room: "Living room",
            lastScene: makeLastSceneStore(saved: lastScene),
            face: { FaceStub(mood: $0) },
            haptics: haptics,
            clock: clock.now,
            schedule: scheduleSpy.schedule,
            actionHandler: actionHandler
        )
        trackMemoryLeak(loader, file: file, line: line)
        trackMemoryLeak(healthLoader, file: file, line: line)
        trackMemoryLeak(connectionLoader, file: file, line: line)
        trackMemoryLeak(speechLoader, file: file, line: line)
        trackMemoryLeak(haptics, file: file, line: line)
        return (sut, loader, healthLoader, connectionLoader)
    }

    func makeLastSceneStore(saved scene: PlantMonitorScene) -> PlantLastSceneStore {
        let store = PlantLastSceneStore(defaults: DefaultsSpy())
        store.save(scene)
        return store
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

    /// Completes only on demand, so the bubble keeps the template line until then.
    @MainActor
    final class SpeechLoaderStub: PlantSpeechLoader {
        private(set) var requestCount = 0

        private var completions: [(PlantSpeechLoader.Result) -> Void] = []
        func load(mood: PlantMood, isSleeping: Bool, reading: PlantReading?, completion: @escaping (PlantSpeechLoader.Result) -> Void) {
            requestCount += 1
            completions.append(completion)
        }

        func complete(with line: String, at index: Int = 0) {
            completions[index](.success(line))
        }
    }

    @MainActor
    final class ScheduleSpy {
        private(set) var intervals: [TimeInterval] = []
        private var ticks: [@MainActor @Sendable () -> Bool] = []

        func schedule(interval: TimeInterval, tick: @escaping @MainActor @Sendable () -> Bool) {
            intervals.append(interval)
            ticks.append(tick)
        }

        @discardableResult
        func fire(at index: Int = 0) -> Bool {
            ticks[index]()
        }
    }

    final class ClockStub {
        private var date: Date
        init(at date: Date) { self.date = date }
        var now: () -> Date { { self.date } }
        func advance(by seconds: TimeInterval) { date = date.addingTimeInterval(seconds) }
    }

    /// Today at `hour`:00 in the current calendar, which the composer reads the sky with.
    func time(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date(timeIntervalSince1970: 1_000_000))!
    }

    @MainActor
    final class HapticsSpy: PlantHapticsClient {
        private(set) var played: [PlantHaptic] = []
        func play(_ haptic: PlantHaptic) { played.append(haptic) }
        func clear() { played.removeAll() }
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
    final class ConnectionLoaderStub: PlantConnectionLoader {
        enum Message: Equatable {
            case subscribeConnection
        }

        var messages: [Message] = []

        private var subscriptions: [(PlantConnection) -> Void] = []
        func subscribe(update: @escaping (PlantConnection) -> Void) {
            messages.append(.subscribeConnection)
            subscriptions.append(update)
        }

        func complete(with connection: PlantConnection, at index: Int = 0) {
            subscriptions[index](connection)
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

    final class DefaultsSpy: DefaultsClient {
        private var strings: [String: String] = [:]

        func set(_ value: Double, forKey key: String) {}
        func retrieve(forKey key: String) -> Double? { nil }
        func set(_ value: String, forKey key: String) { strings[key] = value }
        func retrieveString(forKey key: String) -> String? { strings[key] }
        func set(_ value: Bool, forKey key: String) {}
        func retrieveBool(forKey key: String) -> Bool? { nil }
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
