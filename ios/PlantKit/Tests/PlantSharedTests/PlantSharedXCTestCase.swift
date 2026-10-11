import PlantShared
import XCTest

@MainActor
class PlantSharedXCTestCase: XCTestCase {
    func makeCalibration(dry: Int, wet: Int, file: StaticString = #filePath, line: UInt = #line) throws -> MoistureCalibration {
        try XCTUnwrap(MoistureCalibration(dryMillivolts: dry, wetMillivolts: wet), file: file, line: line)
    }

    func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 2026-01-01 08:00 UTC.
    func morningDate() -> Date {
        Date(timeIntervalSince1970: 1_767_254_400)
    }

    func makeReading(
        moisture: Double? = 50,
        lux: Int? = 1_000,
        temperature: Double? = 23.5,
        humidity: Double? = 55.2,
        batteryMillivolts: Int? = nil,
        sequence: UInt32 = 42,
        receivedAt: Date = Date(timeIntervalSince1970: 1_767_254_400)
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

    /// Raw fields of a Readings packet. PlantShared tests can't use the PlantMonitor mapper.
    struct ReadingPacket: Equatable {
        let version: UInt8
        let flags: UInt8
        let soilMillivolts: UInt16
        let lux: UInt16
        let temperatureCenti: Int16
        let humidityCenti: UInt16
        let batteryMillivolts: UInt16
        let sequence: UInt32
    }

    func decode(_ data: Data, file: StaticString = #filePath, line: UInt = #line) -> ReadingPacket? {
        guard data.count == PlantBluetoothContract.readingLength else {
            XCTFail("Expected \(PlantBluetoothContract.readingLength) bytes, got \(data.count)", file: file, line: line)
            return nil
        }
        let bytes = [UInt8](data)
        let uint16 = { (offset: Int) in UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8 }
        return ReadingPacket(
            version: bytes[0],
            flags: bytes[1],
            soilMillivolts: uint16(2),
            lux: uint16(4),
            temperatureCenti: Int16(bitPattern: uint16(6)),
            humidityCenti: uint16(8),
            batteryMillivolts: uint16(10),
            sequence: UInt32(uint16(12)) | UInt32(uint16(14)) << 16
        )
    }

    @MainActor
    final class DefaultsSpy: DefaultsClient {
        enum Message: Equatable {
            case set(Double, forKey: String)
            case retrieve(forKey: String)
        }

        private(set) var messages: [Message] = []
        private var stubbed: [String: Double] = [:]

        func stub(_ value: Double, forKey key: String) {
            stubbed[key] = value
        }

        func set(_ value: Double, forKey key: String) {
            messages.append(.set(value, forKey: key))
        }

        func retrieve(forKey key: String) -> Double? {
            messages.append(.retrieve(forKey: key))
            return stubbed[key]
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

        /// Fires the scheduled tick and returns whether the schedule should keep running.
        @discardableResult
        func tick(times: Int = 1, at index: Int = 0) -> Bool {
            var keepTicking = true
            for _ in 0..<times {
                keepTicking = ticks[index]()
            }
            return keepTicking
        }
    }
}
