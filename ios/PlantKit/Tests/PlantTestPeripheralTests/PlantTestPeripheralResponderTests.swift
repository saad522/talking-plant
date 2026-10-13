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
}
#endif
