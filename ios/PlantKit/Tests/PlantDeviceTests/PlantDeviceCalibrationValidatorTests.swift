import PlantShared
import XCTest
@testable import PlantDevice

final class PlantDeviceCalibrationValidatorTests: XCTestCase {
    func test_validate_failsWhenDryIsMissing() {
        XCTAssertEqual(PlantDeviceCalibrationValidator.validate(dry: nil, wet: 1000), .failure(.missingDry))
    }

    func test_validate_failsWhenWetIsMissing() {
        XCTAssertEqual(PlantDeviceCalibrationValidator.validate(dry: 2400, wet: nil), .failure(.missingWet))
    }

    func test_validate_failsWhenWetEqualsDry() {
        XCTAssertEqual(PlantDeviceCalibrationValidator.validate(dry: 2000, wet: 2000), .failure(.wetNotBelowDry))
    }

    func test_validate_failsWhenWetIsAboveDry() {
        XCTAssertEqual(PlantDeviceCalibrationValidator.validate(dry: 1000, wet: 2000), .failure(.wetNotBelowDry))
    }

    func test_validate_failsWhenRangeIsBelow300() {
        XCTAssertEqual(PlantDeviceCalibrationValidator.validate(dry: 1299, wet: 1000), .failure(.rangeTooSmall))
    }

    func test_validate_deliversCalibrationWhenRangeIs300() {
        XCTAssertEqual(
            PlantDeviceCalibrationValidator.validate(dry: 1300, wet: 1000),
            .success(MoistureCalibration(dryMillivolts: 1300, wetMillivolts: 1000)!)
        )
    }

    func test_isNearADCLimit_isTrueFrom2480() {
        XCTAssertFalse(PlantDeviceCalibrationValidator.isNearADCLimit(dry: 2479))
        XCTAssertTrue(PlantDeviceCalibrationValidator.isNearADCLimit(dry: 2480))
    }
}
