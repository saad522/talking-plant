import Foundation
import Testing
import PlantKit

struct DeviceInfoTests {
    @Test func decodesDeviceInfo() throws {
        let info = try DeviceInfo(data: Data([0x01, 0x01, 0x02, 0x03, 0x00, 0x00, 0x2C, 0x01]))
        #expect(info.protocolVersion == 1)
        #expect(info.firmwareMajor == 1)
        #expect(info.firmwareMinor == 2)
        #expect(info.firmwarePatch == 3)
        #expect(info.firmwareVersion == "1.2.3")
        #expect(info.capabilities.isEmpty)
        #expect(info.intervalSeconds == 300)
    }

    @Test func decodesCapabilitiesAndMaxInterval() throws {
        let info = try DeviceInfo(data: Data([0x01, 0x00, 0x00, 0x00, 0x07, 0x00, 0xFF, 0xFF]))
        #expect(info.capabilities == [.pump, .display, .batterySense])
        #expect(info.intervalSeconds == UInt16.max)

        let pumpOnly = try DeviceInfo(data: Data([0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x1E, 0x00]))
        #expect(pumpOnly.capabilities == .pump)
        #expect(pumpOnly.intervalSeconds == 30)
    }

    @Test(arguments: [0, 7, 9, 16])
    func rejectsWrongLength(length: Int) {
        #expect(throws: PlantContractError.wrongLength(expected: 8, actual: length)) {
            try DeviceInfo(data: Data(repeating: 0x01, count: length))
        }
    }
}
