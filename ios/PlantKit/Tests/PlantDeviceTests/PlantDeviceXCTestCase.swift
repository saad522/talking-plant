import PlantDevice
import XCTest

@MainActor
class PlantDeviceXCTestCase: XCTestCase {
    func makeDeviceInfoPacket(
        protocolVersion: UInt8 = 1,
        firmware: (major: UInt8, minor: UInt8, patch: UInt8) = (1, 2, 3),
        capabilities: UInt8 = 0,
        intervalSeconds: [UInt8] = [0x2C, 0x01]
    ) -> Data {
        Data([protocolVersion, firmware.major, firmware.minor, firmware.patch, capabilities, 0x00] + intervalSeconds)
    }
}
