import XCTest
@testable import PlantHistory

@MainActor
final class PlantHistoryChartViewModelTests: PlantHistoryXCTestCase {
    func test_init_deliversLocalisedTitleForEachMetric() {
        let expected: [PlantHistoryMetric: String] = [
            .moisture: String.localised(key: "plant.history.moisture.title"),
            .light: String.localised(key: "plant.history.light.title"),
            .temperature: String.localised(key: "plant.history.temperature.title"),
            .humidity: String.localised(key: "plant.history.humidity.title"),
        ]

        PlantHistoryMetric.allCases.forEach { metric in
            XCTAssertEqual(PlantHistoryChartViewModel(metric: metric, samples: []).title, expected[metric], "\(metric)")
        }
    }

    func test_init_deliversPointsForMetricSkippingMissingValues() {
        let samples = [
            makeSample(date: anyDate(), moisture: 40, lux: 900),
            makeSample(date: anyDate().addingTimeInterval(600), moisture: nil, lux: 950),
            makeSample(date: anyDate().addingTimeInterval(1_200), moisture: 44, lux: nil),
        ]

        let moisture = PlantHistoryChartViewModel(metric: .moisture, samples: samples)
        let light = PlantHistoryChartViewModel(metric: .light, samples: samples)

        XCTAssertEqual(moisture.points, [
            PlantHistoryChartPoint(date: anyDate(), value: 40),
            PlantHistoryChartPoint(date: anyDate().addingTimeInterval(1_200), value: 44),
        ])
        XCTAssertEqual(light.points, [
            PlantHistoryChartPoint(date: anyDate(), value: 900),
            PlantHistoryChartPoint(date: anyDate().addingTimeInterval(600), value: 950),
        ])
    }

    func test_init_deliversLatestValueFormattedForEachMetric() {
        let samples = [
            makeSample(date: anyDate(), moisture: 10, lux: 10, temperature: 10, humidity: 10),
            makeSample(date: anyDate().addingTimeInterval(600), moisture: 42.4, lux: 1_199.6, temperature: 21.46, humidity: 60),
        ]

        let values = PlantHistoryMetric.allCases.map { PlantHistoryChartViewModel(metric: $0, samples: samples).latestValue }

        XCTAssertEqual(values, ["42%", "1,200 lx", "21.5 °C", "60%"])
    }

    func test_init_deliversPlaceholderWhenMetricHasNoValues() {
        let samples = [makeSample(moisture: nil, lux: nil, temperature: nil, humidity: nil)]

        let values = PlantHistoryMetric.allCases.map { PlantHistoryChartViewModel(metric: $0, samples: samples).latestValue }

        XCTAssertEqual(values, ["–", "–", "–", "–"])
    }

    func test_strings_haveValueForEveryKey() {
        let keys = [
            "plant.history.title",
            "plant.history.range.day",
            "plant.history.range.week",
            "plant.history.moisture.title",
            "plant.history.light.title",
            "plant.history.temperature.title",
            "plant.history.humidity.title",
            "plant.history.empty.description",
            "plant.history.error.description",
        ]

        keys.forEach { key in
            XCTAssertNotEqual(String.localised(key: key), key, "Missing string for \(key)")
        }
    }
}
