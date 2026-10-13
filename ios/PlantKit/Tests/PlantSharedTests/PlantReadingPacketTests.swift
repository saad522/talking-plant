import PlantShared
import XCTest

@MainActor
final class PlantReadingPacketTests: PlantSharedXCTestCase {
    // BLE_CONTRACT.md fixture: soil 2500, lux 1000, 23.50 C, 55.20 %, sequence 42.
    private let contractFixture = Data([
        0x01, 0x07, 0xC4, 0x09, 0xE8, 0x03, 0x2E, 0x09,
        0x90, 0x15, 0x00, 0x00, 0x2A, 0x00, 0x00, 0x00,
    ])

    func test_init_decodesContractFixtureFields() throws {
        let sut = try XCTUnwrap(PlantReadingPacket(data: contractFixture))

        XCTAssertEqual(sut.version, 1)
        XCTAssertEqual(sut.flags, 0b0111)
        XCTAssertEqual(sut.soilMillivolts, 2_500)
        XCTAssertEqual(sut.lux, 1_000)
        XCTAssertEqual(sut.temperatureCenti, 2_350)
        XCTAssertEqual(sut.humidityCenti, 5_520)
        XCTAssertEqual(sut.batteryMillivolts, 0)
        XCTAssertEqual(sut.sequence, 42)
    }

    func test_init_returnsNilOnWrongLength() {
        [0, 1, 15, 17, 32].forEach { length in
            let data = (contractFixture + contractFixture).prefix(length)

            XCTAssertNil(PlantReadingPacket(data: data), "length \(length)")
        }
    }

    func test_init_decodesNegativeTemperature() throws {
        let data = packet(replacingAt: 6, with: [0xE6, 0xFB])

        XCTAssertEqual(try XCTUnwrap(PlantReadingPacket(data: data)).temperatureCenti, -1_050)
    }

    func test_init_decodesSequenceLittleEndian() throws {
        let data = packet(replacingAt: 12, with: [0x04, 0x03, 0x02, 0x01])

        XCTAssertEqual(try XCTUnwrap(PlantReadingPacket(data: data)).sequence, 0x0102_0304)
    }

    func test_init_keepsFlagsRawAndVersionUnchecked() throws {
        var data = packet(replacingAt: 1, with: [0xF0])
        data = packet(data, replacingAt: 0, with: [0x02])

        let sut = try XCTUnwrap(PlantReadingPacket(data: data))

        XCTAssertEqual(sut.version, 2)
        XCTAssertEqual(sut.flags, 0xF0)
    }

    func test_init_decodesDataSlice() throws {
        let padded = Data([0xFF, 0xFF]) + contractFixture + Data([0xFF])

        XCTAssertEqual(PlantReadingPacket(data: padded[2..<18]), PlantReadingPacket(data: contractFixture))
    }

    func test_has_followsEachFlagBit() throws {
        let cases: [(flags: UInt8, flag: PlantReadingPacket.Flag)] = [
            (0b0001, .soil), (0b0010, .light), (0b0100, .environment), (0b1000, .battery),
        ]

        for (flags, flag) in cases {
            let sut = try XCTUnwrap(PlantReadingPacket(data: packet(replacingAt: 1, with: [flags])))

            XCTAssertTrue(sut.has(flag), "flags \(flags)")
            XCTAssertFalse(try XCTUnwrap(PlantReadingPacket(data: packet(replacingAt: 1, with: [0]))).has(flag))
        }
    }

    // MARK: - Helpers

    private func packet(_ base: Data? = nil, replacingAt offset: Int, with bytes: [UInt8]) -> Data {
        var data = [UInt8](base ?? contractFixture)
        data.replaceSubrange(offset..<offset + bytes.count, with: bytes)
        return Data(data)
    }
}
