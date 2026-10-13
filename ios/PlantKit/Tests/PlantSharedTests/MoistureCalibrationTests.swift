import PlantShared
import XCTest

@MainActor
final class MoistureCalibrationTests: PlantSharedXCTestCase {
    func test_placeholder_hasDefaultValuesAndIsNotCalibrated() {
        let calibration = MoistureCalibration.placeholder

        XCTAssertEqual(calibration.dryMillivolts, 2450)
        XCTAssertEqual(calibration.wetMillivolts, 1050)
        XCTAssertFalse(calibration.isCalibrated)
    }

    func test_init_isCalibratedOnValidRange() throws {
        let calibration = try makeCalibration(dry: 2450, wet: 1050)

        XCTAssertTrue(calibration.isCalibrated)
        XCTAssertNotEqual(calibration, .placeholder)
    }

    func test_moisturePercent_followsFormulaAndClampsToRange() {
        let cases: [(soil: Int, expected: Double)] = [
            (2450, 0),     // dry endpoint
            (1050, 100),   // wet endpoint
            (1750, 50),    // midpoint
            (2100, 25),
            (2500, 0),     // drier than dry clamps to 0
            (3300, 0),
            (1000, 100),   // wetter than wet clamps to 100
            (0, 100),
        ]

        cases.forEach { soil, expected in
            XCTAssertEqual(
                MoistureCalibration.placeholder.moisturePercent(soilMillivolts: soil),
                expected,
                "soil \(soil) mV"
            )
        }
    }

    func test_moisturePercent_convertsContractFixtureSoilReading() throws {
        // 2500 mV from the contract fixture is drier than the placeholder dry point.
        XCTAssertEqual(MoistureCalibration.placeholder.moisturePercent(soilMillivolts: 2500), 0)

        let calibration = try makeCalibration(dry: 3000, wet: 1000)

        XCTAssertEqual(calibration.moisturePercent(soilMillivolts: 2500), 25)
    }

    func test_init_returnsNilWhenDryIsNotAboveWet() {
        let cases: [(dry: Int, wet: Int)] = [(1050, 1050), (1050, 2450), (0, 1)]

        cases.forEach { dry, wet in
            XCTAssertNil(MoistureCalibration(dryMillivolts: dry, wetMillivolts: wet), "dry \(dry), wet \(wet)")
        }
    }

    func test_moisturePercent_handlesNarrowestValidRange() throws {
        let calibration = try makeCalibration(dry: 1001, wet: 1000)

        XCTAssertEqual(calibration.moisturePercent(soilMillivolts: 1001), 0)
        XCTAssertEqual(calibration.moisturePercent(soilMillivolts: 1000), 100)
    }
}
