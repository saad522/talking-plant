import PlantShared
import XCTest
@testable import PlantMonitor

@MainActor
final class PlantReadingMapperTests: PlantMonitorXCTestCase {
    func test_map_deliversReadingOnContractFixture() throws {
        let reading = try map(contractFixture, receivedAt: anyDate())

        XCTAssertEqual(reading, makeReading(
            moisture: 25,
            lux: 1_000,
            temperature: 23.5,
            humidity: 55.2,
            batteryMillivolts: nil,
            sequence: 42,
            receivedAt: anyDate()
        ))
    }

    func test_map_appliesCalibrationToSoilMillivolts() throws {
        let reading = try PlantReadingMapper.map(contractFixture, receivedAt: anyDate(), calibration: .placeholder)

        XCTAssertEqual(reading.moisture, MoistureCalibration.placeholder.moisturePercent(soilMillivolts: 2_500))
    }

    func test_map_decodesDataSlice() throws {
        let padded = Data([0xFF, 0xFF]) + contractFixture + Data([0xFF])
        let slice = padded[2..<18]

        XCTAssertEqual(slice.startIndex, 2)
        XCTAssertEqual(try map(slice), try map(contractFixture))
    }

    func test_map_throwsInvalidDataOnWrongLength() {
        [0, 1, 15, 17, 32].forEach { length in
            let data = (contractFixture + contractFixture).prefix(length)

            assertInvalidData(data, "length \(length)")
        }
    }

    func test_map_throwsInvalidDataOnUnsupportedVersion() {
        [UInt8(0), 2, 0xFF].forEach { version in
            assertInvalidData(makeReadingPacket(version: version), "version \(version)")
        }
    }

    func test_map_deliversNoValuesWhenNoFlagsAreSet() throws {
        let reading = try map(makeReadingPacket(flags: 0))

        XCTAssertNil(reading.moisture)
        XCTAssertNil(reading.lux)
        XCTAssertNil(reading.temperature)
        XCTAssertNil(reading.humidity)
        XCTAssertNil(reading.batteryMillivolts)
        XCTAssertEqual(reading.sequence, 42)
    }

    func test_map_gatesEachFieldByItsOwnFlag() throws {
        let soil = try map(makeReadingPacket(flags: 0b0001))
        let light = try map(makeReadingPacket(flags: 0b0010))
        let environment = try map(makeReadingPacket(flags: 0b0100))
        let battery = try map(makeReadingPacket(flags: 0b1000, batteryMillivolts: 4_200))

        XCTAssertEqual(soil, makeReading(moisture: 25, lux: nil, temperature: nil, humidity: nil))
        XCTAssertEqual(light, makeReading(moisture: nil, lux: 1_000, temperature: nil, humidity: nil))
        XCTAssertEqual(environment, makeReading(moisture: nil, lux: nil, temperature: 23.5, humidity: 55.2))
        XCTAssertEqual(battery, makeReading(moisture: nil, lux: nil, temperature: nil, humidity: nil, batteryMillivolts: 4_200))
    }

    func test_map_ignoresReservedFlagBits() throws {
        let reading = try map(makeReadingPacket(flags: 0xF7))

        XCTAssertEqual(reading, makeReading(moisture: 25, batteryMillivolts: nil))
    }

    func test_map_decodesSignedTemperature() throws {
        let cases: [(bytes: [UInt8], celsius: Double)] = [
            ([0xE6, 0xFB], -10.5),    // -1050
            ([0xFF, 0xFF], -0.01),    // -1
            ([0x00, 0x80], -327.68),  // Int16.min
            ([0xFF, 0x7F], 327.67),   // Int16.max
            ([0x00, 0x00], 0),
        ]

        try cases.forEach { bytes, celsius in
            let reading = try map(packet(contractFixture, replacingAt: 6, with: bytes))

            XCTAssertEqual(reading.temperature, celsius, "bytes \(bytes)")
        }
    }

    func test_map_decodesMaxValues() throws {
        let bytes: [UInt8] = [0x01, 0x0F] + Array(repeating: 0xFF, count: 4) + [0xFF, 0x7F] + Array(repeating: 0xFF, count: 8)
        // Wide enough that 65535 mV lands inside the range instead of clamping.
        let calibration = try XCTUnwrap(MoistureCalibration(dryMillivolts: 65_636, wetMillivolts: 65_436))

        let reading = try PlantReadingMapper.map(Data(bytes), receivedAt: anyDate(), calibration: calibration)

        XCTAssertEqual(reading.moisture, calibration.moisturePercent(soilMillivolts: 65_535))
        XCTAssertEqual(reading.moisture, 50.5)
        XCTAssertEqual(reading.lux, 65_535)
        XCTAssertEqual(reading.temperature, 327.67)
        XCTAssertEqual(reading.humidity, 655.35)
        XCTAssertEqual(reading.batteryMillivolts, 65_535)
        XCTAssertEqual(reading.sequence, 4_294_967_295)
    }

    func test_map_decodesSequenceAsLittleEndian() throws {
        let reading = try map(packet(contractFixture, replacingAt: 12, with: [0x04, 0x03, 0x02, 0x01]))

        XCTAssertEqual(reading.sequence, 0x0102_0304)
    }

    // MARK: - Private helpers

    private func map(_ data: Data, receivedAt: Date = Date(timeIntervalSince1970: 1_000)) throws -> PlantReading {
        try PlantReadingMapper.map(data, receivedAt: receivedAt, calibration: anyCalibration())
    }

    private func packet(_ data: Data, replacingAt offset: Int, with bytes: [UInt8]) -> Data {
        var data = data
        data.replaceSubrange(offset..<offset + bytes.count, with: bytes)
        return data
    }

    private func assertInvalidData(
        _ data: Data,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try map(data), message, file: file, line: line) { error in
            XCTAssertEqual(error as? PlantReadingMapper.Error, .invalidData, message, file: file, line: line)
        }
    }
}
