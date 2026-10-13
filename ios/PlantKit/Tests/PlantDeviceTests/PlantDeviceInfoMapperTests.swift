import XCTest
@testable import PlantDevice

@MainActor
final class PlantDeviceInfoMapperTests: PlantDeviceXCTestCase {
    func test_map_deliversDeviceInfo() throws {
        let info = try PlantDeviceInfoMapper.map(Data([0x01, 0x01, 0x02, 0x03, 0x00, 0x00, 0x2C, 0x01]))

        XCTAssertEqual(info.protocolVersion, 1)
        XCTAssertEqual(info.firmwareMajor, 1)
        XCTAssertEqual(info.firmwareMinor, 2)
        XCTAssertEqual(info.firmwarePatch, 3)
        XCTAssertEqual(info.firmwareVersion, "1.2.3")
        XCTAssertTrue(info.capabilities.isEmpty)
        XCTAssertEqual(info.intervalSeconds, 300)
    }

    func test_map_decodesCapabilitiesAndMaxInterval() throws {
        let all = try PlantDeviceInfoMapper.map(makeDeviceInfoPacket(capabilities: 0x07, intervalSeconds: [0xFF, 0xFF]))
        let pumpOnly = try PlantDeviceInfoMapper.map(makeDeviceInfoPacket(capabilities: 0x01, intervalSeconds: [0x1E, 0x00]))

        XCTAssertEqual(all.capabilities, [.pump, .display, .batterySense])
        XCTAssertEqual(all.intervalSeconds, UInt16.max)
        XCTAssertEqual(pumpOnly.capabilities, .pump)
        XCTAssertEqual(pumpOnly.intervalSeconds, 30)
    }

    func test_map_throwsInvalidDataOnWrongLength() {
        for length in [0, 7, 9, 16] {
            XCTAssertThrowsError(try PlantDeviceInfoMapper.map(Data(repeating: 0x01, count: length)), "length \(length)") { error in
                XCTAssertEqual(error as? PeripheralPlantDeviceInfoLoader.Error, .invalidData, "length \(length)")
            }
        }
    }

    func test_map_throwsInvalidDataOnUnsupportedProtocolVersion() {
        for version in [UInt8(0), 2, 255] {
            XCTAssertThrowsError(try PlantDeviceInfoMapper.map(makeDeviceInfoPacket(protocolVersion: version)), "version \(version)") { error in
                XCTAssertEqual(error as? PeripheralPlantDeviceInfoLoader.Error, .invalidData, "version \(version)")
            }
        }
    }
}
