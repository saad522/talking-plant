import XCTest
@testable import PlantDevice

@MainActor
final class PlantDeviceCommandMapperTests: PlantDeviceXCTestCase {
    func test_map_encodesCommandsAsOpcodeAndLittleEndianPayload() {
        XCTAssertEqual(PlantDeviceCommandMapper.map(.readNow), Data([0x01]))
        XCTAssertEqual(PlantDeviceCommandMapper.map(.setInterval(seconds: 300)), Data([0x02, 0x2C, 0x01]))
        XCTAssertEqual(PlantDeviceCommandMapper.map(.setInterval(seconds: 10)), Data([0x02, 0x0A, 0x00]))
        XCTAssertEqual(PlantDeviceCommandMapper.map(.pumpRun(milliseconds: 10_000)), Data([0x10, 0x10, 0x27]))
        XCTAssertEqual(PlantDeviceCommandMapper.map(.pumpRun(milliseconds: UInt16.max)), Data([0x10, 0xFF, 0xFF]))
        XCTAssertEqual(PlantDeviceCommandMapper.map(.pumpStop), Data([0x11]))
    }
}
