import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorFormatterTests: PlantMonitorXCTestCase {
    func test_percent_roundsToWholeNumber() {
        XCTAssertEqual(PlantMonitorFormatter.percent(0), "0%")
        XCTAssertEqual(PlantMonitorFormatter.percent(42.4), "42%")
        XCTAssertEqual(PlantMonitorFormatter.percent(55.6), "56%")
        XCTAssertEqual(PlantMonitorFormatter.percent(100), "100%")
    }

    func test_lux_usesGroupingSeparator() {
        XCTAssertEqual(PlantMonitorFormatter.lux(0), "0 lx")
        XCTAssertEqual(PlantMonitorFormatter.lux(950), "950 lx")
        XCTAssertEqual(PlantMonitorFormatter.lux(65_535), "65,535 lx")
    }

    func test_temperature_usesOneDecimal() {
        XCTAssertEqual(PlantMonitorFormatter.temperature(23.5), "23.5 °C")
        XCTAssertEqual(PlantMonitorFormatter.temperature(21), "21.0 °C")
        XCTAssertEqual(PlantMonitorFormatter.temperature(-10.5), "-10.5 °C")
    }

    func test_formatters_deliverPlaceholderOnNil() {
        XCTAssertEqual(PlantMonitorFormatter.percent(nil), "–")
        XCTAssertEqual(PlantMonitorFormatter.lux(nil), "–")
        XCTAssertEqual(PlantMonitorFormatter.temperature(nil), "–")
    }

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
