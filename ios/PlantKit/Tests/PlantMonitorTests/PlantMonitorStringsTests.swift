import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorStringsTests: PlantMonitorXCTestCase {
    func test_strings_haveValueForEveryKey() {
        let keys = [
            "plant.monitor.history.label",
            "plant.monitor.moisture.title",
            "plant.monitor.light.title",
            "plant.monitor.temperature.title",
            "plant.monitor.humidity.title",
            "plant.monitor.error.dismiss.label",
            "plant.monitor.connectivity.error.description",
            "plant.monitor.general.error.description",
        ]

        keys.forEach { key in
            XCTAssertNotEqual(String.localised(key: key), key, "Missing string for \(key)")
        }
    }
}
