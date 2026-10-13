import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class LocalMoistureCalibrationLoaderTests: PlantDeviceXCTestCase {
    func test_init_doesNotMessageDefaults() {
        let (_, defaults) = makeSUT()

        XCTAssertEqual(defaults.messages, [])
    }

    func test_load_deliversPlaceholderWhenNothingIsSaved() {
        let (sut, defaults) = makeSUT()

        XCTAssertEqual(sut.load(), .placeholder)
        XCTAssertEqual(defaults.messages, [.retrieveDouble(forKey: "plant.device.calibration.dryMillivolts")])
    }

    func test_load_deliversPlaceholderWhenOnlyOneValueIsSaved() {
        let (sut, defaults) = makeSUT()
        defaults.stub(2300.0, forKey: "plant.device.calibration.dryMillivolts")

        XCTAssertEqual(sut.load(), .placeholder)
    }

    func test_save_roundTrips() throws {
        let (sut, defaults) = makeSUT()
        let calibration = try XCTUnwrap(MoistureCalibration(dryMillivolts: 2300, wetMillivolts: 1000))

        sut.save(calibration)

        XCTAssertEqual(defaults.messages, [
            .setDouble(2300, forKey: "plant.device.calibration.dryMillivolts"),
            .setDouble(1000, forKey: "plant.device.calibration.wetMillivolts"),
        ])
        XCTAssertEqual(sut.load(), calibration)
        XCTAssertTrue(sut.load().isCalibrated)
    }

    func test_load_deliversPlaceholderForInvalidSavedPair() {
        let pairs: [(Double, Double)] = [(1000, 1000), (1000, 2000), (0, 0), (2300, 0), (0, 1000)]
        for (dry, wet) in pairs {
            let (sut, defaults) = makeSUT()
            defaults.stub(dry, forKey: "plant.device.calibration.dryMillivolts")
            defaults.stub(wet, forKey: "plant.device.calibration.wetMillivolts")

            XCTAssertEqual(sut.load(), .placeholder, "dry \(dry), wet \(wet)")
        }
    }

    func test_reset_makesLoadDeliverPlaceholder() throws {
        let (sut, defaults) = makeSUT()
        sut.save(try XCTUnwrap(MoistureCalibration(dryMillivolts: 2300, wetMillivolts: 1000)))

        sut.reset()

        XCTAssertEqual(defaults.messages.suffix(2), [
            .setDouble(0, forKey: "plant.device.calibration.dryMillivolts"),
            .setDouble(0, forKey: "plant.device.calibration.wetMillivolts"),
        ])
        XCTAssertEqual(sut.load(), .placeholder)
    }

    // MARK: - Private helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: LocalMoistureCalibrationLoader, defaults: DefaultsSpy) {
        let defaults = DefaultsSpy()
        let sut = LocalMoistureCalibrationLoader(defaults: defaults)
        trackMemoryLeak(defaults, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, defaults)
    }
}
