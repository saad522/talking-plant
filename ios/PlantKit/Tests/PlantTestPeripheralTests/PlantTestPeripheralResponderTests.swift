#if DEBUG
import PlantShared
import XCTest
@testable import PlantDevice
import PlantTestPeripheral

@MainActor
final class PlantTestPeripheralResponderTests: PlantTestPeripheralXCTestCase {
    func test_deviceInfo_matchesContractBytesFor30Seconds() {
        XCTAssertEqual(makeSUT(intervalSeconds: 30).deviceInfo, Data([0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x1E, 0x00]))
    }

    func test_deviceInfo_matchesContractBytesFor300Seconds() {
        XCTAssertEqual(makeSUT(intervalSeconds: 300).deviceInfo, Data([0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x2C, 0x01]))
    }

    func test_deviceInfo_decodesWithTheAppMapper() throws {
        let info = try PlantDeviceInfoMapper.map(makeSUT(intervalSeconds: 300).deviceInfo)

        XCTAssertEqual(info.protocolVersion, PlantBluetoothContract.protocolVersion)
        XCTAssertEqual(info.firmwareVersion, "0.1.0")
        XCTAssertTrue(info.capabilities.isEmpty)
        XCTAssertEqual(info.intervalSeconds, 300)
        XCTAssertEqual(makeSUT().deviceInfo.count, PlantBluetoothContract.deviceInfoLength)
    }

    func test_handle_readNowOnOpcode01() {
        var sut = makeSUT()

        XCTAssertEqual(sut.handle(command: Data([0x01])), .readNow)
        XCTAssertEqual(sut.intervalSeconds, 30)
    }

    func test_handle_setsIntervalFromLittleEndianPayload() {
        var sut = makeSUT()

        XCTAssertEqual(sut.handle(command: Data([0x02, 0x2C, 0x01])), .setInterval(seconds: 300))
        XCTAssertEqual(sut.intervalSeconds, 300)
        XCTAssertEqual(sut.deviceInfo, Data([0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x2C, 0x01]))
    }

    func test_handle_clampsIntervalTo10And3600() {
        var sut = makeSUT()

        XCTAssertEqual(sut.handle(command: Data([0x02, 0x05, 0x00])), .setInterval(seconds: 10))
        XCTAssertEqual(sut.handle(command: Data([0x02, 0xFF, 0xFF])), .setInterval(seconds: 3_600))
        XCTAssertEqual(sut.intervalSeconds, 3_600)
    }

    func test_handle_ignoresShortAndUnknownCommands() {
        var sut = makeSUT()

        for command in [Data(), Data([0x02]), Data([0x02, 0x2C]), Data([0x7F]), Data([0x10, 0xE8, 0x03]), Data([0x11])] {
            XCTAssertEqual(sut.handle(command: command), .ignored, "\(Array(command))")
        }
        XCTAssertEqual(sut.intervalSeconds, 30)
    }

    func test_handle_ignoresBytesAfterThePayload() {
        var sut = makeSUT()

        XCTAssertEqual(sut.handle(command: Data([0x01, 0xAA, 0xBB])), .readNow)
        XCTAssertEqual(sut.handle(command: Data([0x02, 0x2C, 0x01, 0xAA])), .setInterval(seconds: 300))
    }

    func test_handle_readsSlicedDataCorrectly() {
        var sut = makeSUT()
        let slice = Data([0xFF, 0x02, 0x2C, 0x01]).dropFirst()

        XCTAssertEqual(sut.handle(command: slice), .setInterval(seconds: 300))
    }

    // MARK: - Soil override

    private let packet = Data([0x01, 0x07, 0xC4, 0x09, 0xE8, 0x03, 0x00, 0x00, 0xC6, 0x09, 0x70, 0x14, 0x2A, 0x00, 0x00, 0x00])

    func test_readings_withoutOverrideReturnsSameBytes() {
        XCTAssertEqual(makeSUT().readings(from: packet), packet)
    }

    func test_readings_overrideReplacesSoilBytesOnly() {
        var sut = makeSUT()
        sut.soilOverrideMillivolts = 2_450

        let result = sut.readings(from: packet)

        XCTAssertEqual(Array(result[2...3]), [0x92, 0x09])
        XCTAssertEqual(Array(result[0..<2]), Array(packet[0..<2]))
        XCTAssertEqual(Array(result[4...]), Array(packet[4...]))
    }

    func test_readings_overrideSetsSoilValidBitWhenClear() {
        var sut = makeSUT()
        sut.soilOverrideMillivolts = 1_050
        var invalidSoil = packet
        invalidSoil[1] = 0x06

        let result = sut.readings(from: invalidSoil)

        XCTAssertEqual(result[1], 0x07)
        XCTAssertEqual(Array(result[2...3]), [0x1A, 0x04])
    }

    func test_readings_overrideZeroGivesZeroBytesWithSoilValid() {
        var sut = makeSUT()
        sut.soilOverrideMillivolts = 0
        var invalidSoil = packet
        invalidSoil[1] = 0x00

        let result = sut.readings(from: invalidSoil)

        XCTAssertEqual(result[1], 0x01)
        XCTAssertEqual(Array(result[2...3]), [0x00, 0x00])
    }

    func test_readings_clearingOverrideRestoresOriginal() {
        var sut = makeSUT()
        sut.soilOverrideMillivolts = 2_450
        sut.soilOverrideMillivolts = nil

        XCTAssertEqual(sut.readings(from: packet), packet)
    }

    func test_readings_overrideLeavesTooShortPacketAlone() {
        var sut = makeSUT()
        sut.soilOverrideMillivolts = 2_450

        XCTAssertEqual(sut.readings(from: Data([0x01, 0x00])), Data([0x01, 0x00]))
    }
}
#endif
