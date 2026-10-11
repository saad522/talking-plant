import XCTest
@testable import PlantMonitor

@MainActor
final class PlantSensorCardViewModelTests: PlantMonitorXCTestCase {
    func test_init_deliversLocalisedTitleForEachKind() {
        let expected: [PlantSensorKind: String] = [
            .moisture: String.localised(key: "plant.monitor.moisture.title"),
            .light: String.localised(key: "plant.monitor.light.title"),
            .temperature: String.localised(key: "plant.monitor.temperature.title"),
            .humidity: String.localised(key: "plant.monitor.humidity.title"),
        ]

        PlantSensorKind.allCases.forEach { kind in
            XCTAssertEqual(PlantSensorCardViewModel(kind: kind, reading: makeReading()).title, expected[kind], "\(kind)")
        }
    }

    func test_init_deliversFormattedValueForEachKind() {
        let reading = makeReading(moisture: 42.4, lux: 1_200, temperature: 21.46, humidity: 60)

        XCTAssertEqual(values(for: reading), ["42%", "1,200 lx", "21.5 °C", "60%"])
    }

    func test_init_deliversPlaceholderForMissingValues() {
        let reading = makeReading(moisture: nil, lux: nil, temperature: nil, humidity: nil)

        XCTAssertEqual(values(for: reading), ["–", "–", "–", "–"])
    }

    // MARK: - Private helpers

    private func values(for reading: PlantReading) -> [String] {
        PlantSensorKind.allCases.map { PlantSensorCardViewModel(kind: $0, reading: reading).value }
    }
}
