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

        func scan(update: @escaping (PeripheralAdvertisement) -> Void) {
            messages.append(.scan)
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
}
