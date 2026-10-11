import PlantMonitor
import PlantShared
import XCTest

@MainActor
class PlantMonitorXCTestCase: XCTestCase {
    /// Fixture from docs/BLE_CONTRACT.md.
    let contractFixture = Data([
        0x01, 0x07, 0xC4, 0x09, 0xE8, 0x03, 0x2E, 0x09,
        0x90, 0x15, 0x00, 0x00, 0x2A, 0x00, 0x00, 0x00,
    ])

    func anyNSError() -> NSError {
        NSError(domain: "any", code: 1)
    }

    func anyDate() -> Date {
        Date(timeIntervalSince1970: 1_000)
    }

    /// 2500 mV maps to 25%, so soil values are distinguishable from the clamped ends.
    func anyCalibration() -> MoistureCalibration {
        MoistureCalibration(dryMillivolts: 3_000, wetMillivolts: 1_000)!
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

    func makeReadingPacket(
        version: UInt8 = 1,
        flags: UInt8 = 0b0111,
        soilMillivolts: UInt16 = 2_500,
        lux: UInt16 = 1_000,
        temperatureCenti: Int16 = 2_350,
        humidityCenti: UInt16 = 5_520,
        batteryMillivolts: UInt16 = 0,
        sequence: UInt32 = 42
    ) -> Data {
        var data = Data([version, flags])
        [soilMillivolts, lux, UInt16(bitPattern: temperatureCenti), humidityCenti, batteryMillivolts]
            .forEach { value in withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        withUnsafeBytes(of: sequence.littleEndian) { data.append(contentsOf: $0) }
        return data
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

        private var subscriptions: [(PeripheralClient.Result) -> Void] = []
        func subscribe(to characteristic: PlantCharacteristic, update: @escaping (PeripheralClient.Result) -> Void) {
            messages.append(.subscribe(characteristic))
            subscriptions.append(update)
        }

        func completeSubscription(with data: Data, at index: Int = 0) {
            subscriptions[index](.success(data))
        }

        func completeSubscription(with error: Error, at index: Int = 0) {
            subscriptions[index](.failure(error))
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
