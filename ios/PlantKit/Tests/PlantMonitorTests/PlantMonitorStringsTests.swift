import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorStringsTests: PlantMonitorXCTestCase {
    func test_strings_haveValueForEveryKey() {
        let keys = [
            "plant.monitor.history.label",
            "plant.monitor.talk.label",
            "plant.monitor.water.label",
            "plant.monitor.header.subtitle",
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
            "plant.monitor.mood.happy.speech",
            "plant.monitor.mood.thirsty.speech",
            "plant.monitor.mood.veryThirsty.speech",
            "plant.monitor.mood.drowning.speech",
            "plant.monitor.mood.tooDark.speech",
            "plant.monitor.mood.tooHot.speech",
            "plant.monitor.mood.tooCold.speech",
            "plant.monitor.mood.dryAir.speech",
            "plant.monitor.mood.offline.speech",
            "plant.monitor.settings.label",
            "plant.monitor.connection.notPaired.label",
            "plant.monitor.connection.connecting.label",
            "plant.monitor.connection.offline.label",
            "plant.monitor.connection.bluetoothOff.label",
            "plant.monitor.connection.bluetoothUnauthorized.label",
            "plant.monitor.connection.bluetoothUnsupported.label",
            "plant.monitor.connection.incompatible.label",
            "plant.monitor.sleeping.label",
            "plant.monitor.sleeping.speech",
        ]

        keys.forEach { key in
            XCTAssertNotEqual(String.localised(key: key), key, "Missing string for \(key)")
        }
    }
}
