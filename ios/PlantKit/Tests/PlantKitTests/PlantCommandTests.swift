import Foundation
import Testing
import PlantKit

struct PlantCommandTests {
    @Test func encodesCommands() {
        #expect(PlantCommand.readNow.data == Data([0x01]))
        #expect(PlantCommand.setInterval(seconds: 300).data == Data([0x02, 0x2C, 0x01]))
        #expect(PlantCommand.setInterval(seconds: 10).data == Data([0x02, 0x0A, 0x00]))
        #expect(PlantCommand.pumpRun(milliseconds: 10_000).data == Data([0x10, 0x10, 0x27]))
        #expect(PlantCommand.pumpRun(milliseconds: UInt16.max).data == Data([0x10, 0xFF, 0xFF]))
        #expect(PlantCommand.pumpStop.data == Data([0x11]))
    }

    @Test func uuidsMatchContract() {
        #expect(PlantContract.serviceUUID.uuidString == "7697A001-5F72-4B79-B7A4-6632379F2F13")
        #expect(PlantContract.readingsUUID.uuidString == "7697A002-5F72-4B79-B7A4-6632379F2F13")
        #expect(PlantContract.deviceInfoUUID.uuidString == "7697A003-5F72-4B79-B7A4-6632379F2F13")
        #expect(PlantContract.commandUUID.uuidString == "7697A004-5F72-4B79-B7A4-6632379F2F13")
    }
}
