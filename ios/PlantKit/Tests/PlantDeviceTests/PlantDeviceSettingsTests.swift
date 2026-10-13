import XCTest
@testable import PlantDevice

@MainActor
final class PlantDeviceSettingsTests: PlantDeviceXCTestCase {
    func test_init_doesNotMessageDefaults() {
        let (_, defaults) = makeSUT()

        XCTAssertEqual(defaults.messages, [])
    }

    func test_loadMode_deliversSimulatedWhenNothingIsSaved() {
        let (sut, defaults) = makeSUT()

        XCTAssertEqual(sut.loadMode(), .simulated)
        XCTAssertEqual(defaults.messages, [.retrieveString(forKey: "plant.device.mode")])
    }

    func test_loadMode_deliversSimulatedForUnknownRawValue() {
        let (sut, defaults) = makeSUT()
        defaults.stub("hologram", forKey: "plant.device.mode")

        XCTAssertEqual(sut.loadMode(), .simulated)
    }

    func test_saveMode_roundTrips() {
        for mode in [PlantDeviceMode.simulated, .sensor] {
            let (sut, defaults) = makeSUT()

            sut.saveMode(mode)

            XCTAssertEqual(defaults.messages, [.setString(mode.rawValue, forKey: "plant.device.mode")])
            XCTAssertEqual(sut.loadMode(), mode)
        }
    }

    func test_loadPairedDevice_deliversNilWhenNothingIsSaved() {
        let (sut, _) = makeSUT()

        XCTAssertNil(sut.loadPairedDevice())
    }

    func test_savePairedDevice_roundTrips() {
        let (sut, defaults) = makeSUT()
        let device = PlantPairedDevice(identifier: anyIdentifier(), name: "TalkingPlant-A1B2")

        sut.savePairedDevice(device)

        XCTAssertEqual(defaults.messages, [
            .setString(anyIdentifier().uuidString, forKey: "plant.device.paired.identifier"),
            .setString("TalkingPlant-A1B2", forKey: "plant.device.paired.name"),
        ])
        XCTAssertEqual(sut.loadPairedDevice(), device)
    }

    func test_clearPairedDevice_makesLoadDeliverNil() {
        let (sut, defaults) = makeSUT()
        sut.savePairedDevice(PlantPairedDevice(identifier: anyIdentifier(), name: "TalkingPlant-A1B2"))

        sut.clearPairedDevice()

        XCTAssertEqual(defaults.messages.suffix(2), [
            .setString("", forKey: "plant.device.paired.identifier"),
            .setString("", forKey: "plant.device.paired.name"),
        ])
        XCTAssertNil(sut.loadPairedDevice())
    }

    func test_loadPairedDevice_deliversNilForEmptyOrInvalidIdentifier() {
        for identifier in ["", "not-a-uuid"] {
            let (sut, defaults) = makeSUT()
            defaults.stub(identifier, forKey: "plant.device.paired.identifier")
            defaults.stub("TalkingPlant-A1B2", forKey: "plant.device.paired.name")

            XCTAssertNil(sut.loadPairedDevice(), "identifier \(identifier)")
        }
    }

    func test_loadPairedDevice_deliversNilWhenNameIsMissing() {
        let (sut, defaults) = makeSUT()
        defaults.stub(anyIdentifier().uuidString, forKey: "plant.device.paired.identifier")

        XCTAssertNil(sut.loadPairedDevice())
    }

    // MARK: - Private helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: PlantDeviceSettings, defaults: DefaultsSpy) {
        let defaults = DefaultsSpy()
        let sut = PlantDeviceSettings(defaults: defaults)
        trackMemoryLeak(defaults, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, defaults)
    }
}
