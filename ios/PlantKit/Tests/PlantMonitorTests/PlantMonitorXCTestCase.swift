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
}
