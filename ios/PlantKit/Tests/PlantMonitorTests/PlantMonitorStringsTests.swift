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
            "plant.monitor.mood.happy.label",
            "plant.monitor.mood.thirsty.label",
            "plant.monitor.mood.veryThirsty.label",
            "plant.monitor.mood.drowning.label",
            "plant.monitor.mood.tooDark.label",
            "plant.monitor.mood.tooHot.label",
            "plant.monitor.mood.tooCold.label",
            "plant.monitor.mood.dryAir.label",
            "plant.monitor.mood.offline.label",
        ]

        keys.forEach { key in
            XCTAssertNotEqual(String.localised(key: key), key, "Missing string for \(key)")
        }
    }
}
