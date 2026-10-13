import PlantDevice
import PlantDeviceiOS
import PlantShared
import XCTest

@MainActor
class PlantDeviceiOSXCTestCase: XCTestCase {
    func makeSUT(
        savedMode: PlantDeviceMode? = nil,
        actionHandler: @escaping (PlantDeviceAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: PlantDeviceView,
        connection: ConnectionLoaderStub,
        pairing: PairingLoaderStub,
        info: InfoLoaderStub,
        commands: CommandSenderStub,
        defaults: DefaultsSpy
    ) {
        let connection = ConnectionLoaderStub()
        let pairing = PairingLoaderStub()
        let info = InfoLoaderStub()
        let commands = CommandSenderStub()
        let defaults = DefaultsSpy()
        if let savedMode {
            defaults.stub(savedMode.rawValue, forKey: "plant.device.mode")
        }
        let sut = PlantDeviceUIComposer.composed(
            connectionLoader: connection,
            pairingLoader: pairing,
            infoLoader: info,
            calibrationLoader: LocalMoistureCalibrationLoader(defaults: defaults),
            rawReadingLoader: RawReadingLoaderStub(),
            commandSender: commands,
            settings: PlantDeviceSettings(defaults: defaults),
            actionHandler: actionHandler
        )
        trackMemoryLeak(connection, file: file, line: line)
        trackMemoryLeak(pairing, file: file, line: line)
        trackMemoryLeak(info, file: file, line: line)
        trackMemoryLeak(commands, file: file, line: line)
        trackMemoryLeak(defaults, file: file, line: line)
        return (sut, connection, pairing, info, commands, defaults)
    }

    func makeRawSUT(
        showsRawReading: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantDeviceView, connection: ConnectionLoaderStub, raw: RawReadingLoaderStub) {
        let connection = ConnectionLoaderStub()
        let raw = RawReadingLoaderStub()
        let defaults = DefaultsSpy()
        defaults.stub(PlantDeviceMode.sensor.rawValue, forKey: "plant.device.mode")
        let sut = PlantDeviceUIComposer.composed(
            connectionLoader: connection,
            pairingLoader: PairingLoaderStub(),
            infoLoader: InfoLoaderStub(),
            calibrationLoader: LocalMoistureCalibrationLoader(defaults: defaults),
            rawReadingLoader: raw,
            commandSender: CommandSenderStub(),
            settings: PlantDeviceSettings(defaults: defaults),
            showsRawReading: showsRawReading,
            actionHandler: { _ in }
        )
        trackMemoryLeak(connection, file: file, line: line)
        trackMemoryLeak(raw, file: file, line: line)
        trackMemoryLeak(defaults, file: file, line: line)
        return (sut, connection, raw)
    }

    func makeCalibrationSUT(
        savedCalibration: MoistureCalibration? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: PlantDeviceCalibrationView,
        connection: ConnectionLoaderStub,
        raw: RawReadingLoaderStub,
        commands: CommandSenderStub,
        schedule: ScheduleSpy
    ) {
        let connection = ConnectionLoaderStub()
        let raw = RawReadingLoaderStub()
        let commands = CommandSenderStub()
        let defaults = DefaultsSpy()
        let schedule = ScheduleSpy()
        let loader = LocalMoistureCalibrationLoader(defaults: defaults)
        if let savedCalibration { loader.save(savedCalibration) }
        let sut = PlantDeviceUIComposer.composedCalibration(
            calibrationLoader: loader,
            rawReadingLoader: raw,
            connectionLoader: connection,
            commandSender: commands,
            schedule: schedule.schedule
        )
        trackMemoryLeak(connection, file: file, line: line)
        trackMemoryLeak(raw, file: file, line: line)
        trackMemoryLeak(commands, file: file, line: line)
        trackMemoryLeak(defaults, file: file, line: line)
        trackMemoryLeak(schedule, file: file, line: line)
        return (sut, connection, raw, commands, schedule)
    }

    func anyRawReading(soilMillivolts: Int? = 2_431, sequence: UInt32 = 1, flags: UInt8 = 0x07) -> PlantDeviceRawReading {
        PlantDeviceRawReading(
            soilMillivolts: soilMillivolts,
            lux: 312,
            temperature: 23.41,
            humidity: 48.2,
            flags: flags,
            sequence: sequence,
            receivedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func anyNSError() -> NSError {
        NSError(domain: "any", code: 1)
    }

    func anyDeviceInfo(intervalSeconds: UInt16 = 300) -> PlantDeviceInfo {
        PlantDeviceInfo(protocolVersion: 1, firmwareMajor: 0, firmwareMinor: 1, firmwarePatch: 0, capabilities: [], intervalSeconds: intervalSeconds)
    }

    func anyPairedDevice() -> PlantPairedDevice {
        PlantPairedDevice(identifier: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!, name: "TalkingPlant-TEST")
    }

    func trackMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be deallocated. Potential memory leak", file: file, line: line)
        }
    }

    @MainActor
    final class ConnectionLoaderStub: PlantDeviceConnectionLoader {
        private var subscriptions: [(PlantConnection) -> Void] = []
        func subscribe(update: @escaping (PlantConnection) -> Void) {
            subscriptions.append(update)
        }

        func simulate(_ connection: PlantConnection, at index: Int = 0) {
            subscriptions[index](connection)
        }
    }

    @MainActor
    final class PairingLoaderStub: PlantDevicePairingLoader {
        enum Message: Equatable {
            case subscribe
            case pair(PlantDeviceCandidate)
            case forget
            case connectSaved
        }

        private(set) var messages: [Message] = []
        private var subscriptions: [(PlantPairedDevice?) -> Void] = []

        func subscribe(update: @escaping (PlantPairedDevice?) -> Void) {
            messages.append(.subscribe)
            subscriptions.append(update)
        }

        func simulate(_ device: PlantPairedDevice?, at index: Int = 0) {
            subscriptions[index](device)
        }

        func pair(_ candidate: PlantDeviceCandidate) { messages.append(.pair(candidate)) }
        func forget() { messages.append(.forget) }
        func connectSaved() { messages.append(.connectSaved) }
    }

    @MainActor
    final class InfoLoaderStub: PlantDeviceInfoLoader {
        private(set) var loadCount = 0
        private var completions: [(PlantDeviceInfoLoader.Result) -> Void] = []
        func load(completion: @escaping (PlantDeviceInfoLoader.Result) -> Void) {
            loadCount += 1
            completions.append(completion)
        }

        func completeLoad(with info: PlantDeviceInfo, at index: Int = 0) {
            completions[index](.success(info))
        }
    }

    @MainActor
    final class RawReadingLoaderStub: PlantDeviceRawReadingLoader {
        private(set) var loadCount = 0
        private var loadCompletions: [(PlantDeviceRawReadingLoader.Result) -> Void] = []
        func load(completion: @escaping (PlantDeviceRawReadingLoader.Result) -> Void) {
            loadCount += 1
            loadCompletions.append(completion)
        }

        func completeLoad(with reading: PlantDeviceRawReading, at index: Int = 0) {
            loadCompletions[index](.success(reading))
        }

        private var subscriptions: [(PlantDeviceRawReadingLoader.Result) -> Void] = []
        var subscriptionCount: Int { subscriptions.count }
        func subscribe(update: @escaping (PlantDeviceRawReadingLoader.Result) -> Void) {
            subscriptions.append(update)
        }

        func simulate(_ reading: PlantDeviceRawReading, at index: Int = 0) {
            subscriptions[index](.success(reading))
        }

        func simulate(error: Error, at index: Int = 0) {
            subscriptions[index](.failure(error))
        }
    }

    @MainActor
    final class ScheduleSpy {
        private var ticks: [@MainActor @Sendable () -> Bool] = []
        func schedule(_ interval: TimeInterval, _ tick: @escaping @MainActor @Sendable () -> Bool) {
            ticks.append(tick)
        }

        func fire(at index: Int = 0) { _ = ticks[index]() }
    }

    @MainActor
    final class CommandSenderStub: PlantDeviceCommandSender {
        private(set) var commands: [PlantDeviceCommand] = []
        private var completions: [(PlantDeviceCommandSender.Result) -> Void] = []
        func send(_ command: PlantDeviceCommand, completion: @escaping (PlantDeviceCommandSender.Result) -> Void) {
            commands.append(command)
            completions.append(completion)
        }

        func completeSend(with error: Error?, at index: Int = 0) {
            completions[index](error)
        }
    }

    @MainActor
    final class ScanLoaderStub: PlantDeviceScanLoader {
        enum Message: Equatable {
            case start
            case stop
        }

        private(set) var messages: [Message] = []
        private var handlers: [(PlantDeviceCandidate) -> Void] = []

        func start(update: @escaping (PlantDeviceCandidate) -> Void) {
            messages.append(.start)
            handlers.append(update)
        }

        func stop() { messages.append(.stop) }

        func simulate(_ candidate: PlantDeviceCandidate, at index: Int = 0) {
            handlers[index](candidate)
        }
    }

    @MainActor
    final class DefaultsSpy: DefaultsClient {
        private var strings: [String: String] = [:]

        func stub(_ value: String, forKey key: String) {
            strings[key] = value
        }

        func set(_ value: String, forKey key: String) { strings[key] = value }
        func retrieveString(forKey key: String) -> String? { strings[key] }
        private var doubles: [String: Double] = [:]

        func set(_ value: Double, forKey key: String) { doubles[key] = value }
        func retrieve(forKey key: String) -> Double? { doubles[key] }
        func set(_ value: Bool, forKey key: String) {}
        func retrieveBool(forKey key: String) -> Bool? { nil }
    }
}

extension String {
    static func localised(key: String) -> String {
        NSLocalizedString(key, tableName: "PlantDevice", bundle: PlantDeviceBundle.bundle, comment: "")
    }
}
