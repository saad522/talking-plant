import PlantDevice
import PlantShared
import XCTest

@MainActor
class PlantDeviceXCTestCase: XCTestCase {
    /// Fixture from docs/M7 firmware: protocol 1, firmware 1.2.3, no capabilities, 300 s.
    let deviceInfoFixture = Data([0x01, 0x01, 0x02, 0x03, 0x00, 0x00, 0x2C, 0x01])

    func anyNSError() -> NSError {
        NSError(domain: "any", code: 1)
    }

    func makeDeviceInfoPacket(
        protocolVersion: UInt8 = 1,
        firmware: (major: UInt8, minor: UInt8, patch: UInt8) = (1, 2, 3),
        capabilities: UInt8 = 0,
        intervalSeconds: [UInt8] = [0x2C, 0x01]
    ) -> Data {
        Data([protocolVersion, firmware.major, firmware.minor, firmware.patch, capabilities, 0x00] + intervalSeconds)
    }

    func trackMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be deallocated. Potential memory leak", file: file, line: line)
        }
    }

    @MainActor
    final class ClientSpy: PeripheralClient {
        enum Message: Equatable {
            case read(PlantCharacteristic)
            case subscribe(PlantCharacteristic)
            case write(Data, PlantCharacteristic)
        }

        var messages: [Message] = []

        private var readCompletions: [(PeripheralClient.Result) -> Void] = []
        func read(_ characteristic: PlantCharacteristic, completion: @escaping (PeripheralClient.Result) -> Void) {
            messages.append(.read(characteristic))
            readCompletions.append(completion)
        }

        func completeRead(with data: Data, at index: Int = 0) {
            readCompletions[index](.success(data))
        }

        func completeRead(with error: Error, at index: Int = 0) {
            readCompletions[index](.failure(error))
        }

        func subscribe(to characteristic: PlantCharacteristic, update: @escaping (PeripheralClient.Result) -> Void) {
            messages.append(.subscribe(characteristic))
        }

        private var writeCompletions: [(PeripheralClient.WriteResult) -> Void] = []
        func write(_ data: Data, to characteristic: PlantCharacteristic, completion: @escaping (PeripheralClient.WriteResult) -> Void) {
            messages.append(.write(data, characteristic))
            writeCompletions.append(completion)
        }

        func completeWrite(with error: Error?, at index: Int = 0) {
            writeCompletions[index](error)
        }
    }

    @MainActor
    final class ConnectionClientSpy: PeripheralConnectionClient {
        enum Message: Equatable {
            case subscribeState
            case scan
            case stopScan
            case connect(UUID, String)
            case disconnect
        }

        var messages: [Message] = []

        private var stateSubscriptions: [(PeripheralConnectionState) -> Void] = []
        func subscribe(state update: @escaping (PeripheralConnectionState) -> Void) {
            messages.append(.subscribeState)
            stateSubscriptions.append(update)
        }

        func simulateState(_ state: PeripheralConnectionState, at index: Int = 0) {
            stateSubscriptions[index](state)
        }

        private var scanHandlers: [(PeripheralAdvertisement) -> Void] = []
        func scan(update: @escaping (PeripheralAdvertisement) -> Void) {
            messages.append(.scan)
            scanHandlers.append(update)
        }

        func simulateAdvertisement(_ advertisement: PeripheralAdvertisement, at index: Int = 0) {
            scanHandlers[index](advertisement)
        }

        func stopScan() {
            messages.append(.stopScan)
        }

        func connect(to identifier: UUID, name: String) {
            messages.append(.connect(identifier, name))
        }

        func disconnect() {
            messages.append(.disconnect)
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

    @MainActor
    final class DefaultsSpy: DefaultsClient {
        enum Message: Equatable {
            case setString(String, forKey: String)
            case retrieveString(forKey: String)
        }

        private(set) var messages: [Message] = []
        private var strings: [String: String] = [:]

        func stub(_ value: String, forKey key: String) {
            strings[key] = value
        }

        func set(_ value: String, forKey key: String) {
            messages.append(.setString(value, forKey: key))
            strings[key] = value
        }

        func retrieveString(forKey key: String) -> String? {
            messages.append(.retrieveString(forKey: key))
            return strings[key]
        }

        func set(_ value: Double, forKey key: String) {}
        func retrieve(forKey key: String) -> Double? { nil }
        func set(_ value: Bool, forKey key: String) {}
        func retrieveBool(forKey key: String) -> Bool? { nil }
    }

    @MainActor
    final class ConnectionLoaderStub: PlantDeviceConnectionLoader {
        private var subscriptions: [(PlantConnection) -> Void] = []
        var subscriptionCount: Int { subscriptions.count }
        func subscribe(update: @escaping (PlantConnection) -> Void) {
            subscriptions.append(update)
        }

        func simulate(_ connection: PlantConnection, at index: Int = 0) {
            subscriptions[index](connection)
        }
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

        func completeLoad(with error: Error, at index: Int = 0) {
            completions[index](.failure(error))
        }
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

    func anyDeviceInfo() -> PlantDeviceInfo {
        PlantDeviceInfo(protocolVersion: 1, firmwareMajor: 0, firmwareMinor: 1, firmwarePatch: 0, capabilities: [], intervalSeconds: 30)
    }

    func anyIdentifier() -> UUID {
        UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    }
}
