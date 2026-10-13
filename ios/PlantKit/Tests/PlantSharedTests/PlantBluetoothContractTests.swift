import PlantShared
import XCTest

@MainActor
final class PlantBluetoothContractTests: PlantSharedXCTestCase {
    func test_uuids_matchContract() {
        XCTAssertEqual(PlantBluetoothContract.serviceUUID.uuidString, "7697A001-5F72-4B79-B7A4-6632379F2F13")
        XCTAssertEqual(PlantCharacteristic.readings.uuid.uuidString, "7697A002-5F72-4B79-B7A4-6632379F2F13")
        XCTAssertEqual(PlantCharacteristic.deviceInfo.uuid.uuidString, "7697A003-5F72-4B79-B7A4-6632379F2F13")
        XCTAssertEqual(PlantCharacteristic.command.uuid.uuidString, "7697A004-5F72-4B79-B7A4-6632379F2F13")
    }

    func test_characteristicInitFromUUID_findsEachCharacteristic() {
        for characteristic in PlantCharacteristic.allCases {
            XCTAssertEqual(PlantCharacteristic(uuid: characteristic.uuid), characteristic)
        }
    }

    func test_characteristicInitFromUUID_isNilForUnknownUUID() {
        XCTAssertNil(PlantCharacteristic(uuid: UUID()))
        XCTAssertNil(PlantCharacteristic(uuid: PlantBluetoothContract.serviceUUID))
    }
}
