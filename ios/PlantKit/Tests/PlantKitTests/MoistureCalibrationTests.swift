import Testing
import PlantKit

struct MoistureCalibrationTests {
    @Test func placeholderDefaults() {
        let calibration = MoistureCalibration.placeholder
        #expect(calibration.dryMillivolts == 2400)
        #expect(calibration.wetMillivolts == 1100)
        #expect(!calibration.isCalibrated)
    }

    @Test func customCalibrationIsCalibrated() throws {
        let calibration = try #require(MoistureCalibration(dryMillivolts: 2400, wetMillivolts: 1100))
        #expect(calibration.isCalibrated)
        #expect(calibration != .placeholder)
    }

    @Test(arguments: [
        (2400, 0.0),     // dry endpoint
        (1100, 100.0),   // wet endpoint
        (1750, 50.0),    // midpoint
        (2075, 25.0),
        (2500, 0.0),     // drier than dry clamps to 0
        (3300, 0.0),
        (1000, 100.0),   // wetter than wet clamps to 100
        (0, 100.0),
    ])
    func percentages(soil: Int, expected: Double) {
        #expect(MoistureCalibration.placeholder.moisturePercent(soilMillivolts: soil) == expected)
    }

    @Test func fixtureSoilReading() {
        // 2500 mV from the contract fixture is drier than the placeholder dry point.
        #expect(MoistureCalibration.placeholder.moisturePercent(soilMillivolts: 2500) == 0)
        let calibration = MoistureCalibration(dryMillivolts: 3000, wetMillivolts: 1000)!
        #expect(calibration.moisturePercent(soilMillivolts: 2500) == 25)
    }

    @Test(arguments: [(1100, 1100), (1100, 2400), (0, 1)])
    func rejectsInvalidCalibration(dry: Int, wet: Int) {
        #expect(MoistureCalibration(dryMillivolts: dry, wetMillivolts: wet) == nil)
    }

    @Test func narrowestValidRange() throws {
        let calibration = try #require(MoistureCalibration(dryMillivolts: 1001, wetMillivolts: 1000))
        #expect(calibration.moisturePercent(soilMillivolts: 1001) == 0)
        #expect(calibration.moisturePercent(soilMillivolts: 1000) == 100)
    }
}
