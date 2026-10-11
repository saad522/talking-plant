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
            XCTAssertEqual(makeSUT(metric: metric, samples: []).title, expected[metric], "\(metric)")
        }
    }

    func test_init_deliversPointsForMetricSkippingMissingValues() {
        let samples = [
            makeSample(date: anyDate(), moisture: 40, lux: 900),
            makeSample(date: anyDate().addingTimeInterval(600), moisture: nil, lux: 950),
            makeSample(date: anyDate().addingTimeInterval(1_200), moisture: 44, lux: nil),
        ]

        let moisture = makeSUT(metric: .moisture, samples: samples)
        let light = makeSUT(metric: .light, samples: samples)

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

        let values = PlantHistoryMetric.allCases.map { makeSUT(metric: $0, samples: samples).latestValue }

        XCTAssertEqual(values, ["42%", "1,200 lx", "21.5 °C", "60%"])
    }

    func test_init_deliversPlaceholderWhenMetricHasNoValues() {
        let samples = [makeSample(moisture: nil, lux: nil, temperature: nil, humidity: nil)]

        let values = PlantHistoryMetric.allCases.map { makeSUT(metric: $0, samples: samples).latestValue }

        XCTAssertEqual(values, ["–", "–", "–", "–"])
    }

    func test_yDomain_isFixedForMoistureFromZeroForLightAndFittedOtherwise() {
        XCTAssertEqual(makeSUT(metric: .moisture).yDomain, .fixed(0...100))
        XCTAssertEqual(makeSUT(metric: .light).yDomain, .automatic(includesZero: true))
        XCTAssertEqual(makeSUT(metric: .temperature).yDomain, .automatic(includesZero: false))
        XCTAssertEqual(makeSUT(metric: .humidity).yDomain, .automatic(includesZero: false))
    }

    func test_xDomain_coversWholeRangeEndingOneBucketAfterLatestSample() {
        let samples = [makeSample(date: anyDate()), makeSample(date: anyDate().addingTimeInterval(600))]
        let dayEnd = anyDate().addingTimeInterval(600 + 600)
        let weekEnd = anyDate().addingTimeInterval(600 + 3_600)

        XCTAssertEqual(makeSUT(samples: samples, range: .day).xDomain, dayEnd.addingTimeInterval(-24 * 3_600)...dayEnd)
        XCTAssertEqual(makeSUT(samples: samples, range: .week).xDomain, weekEnd.addingTimeInterval(-7 * 24 * 3_600)...weekEnd)
    }

    func test_xDomain_isSameForMetricsWithMissingLatestValue() {
        let samples = [makeSample(date: anyDate()), makeSample(date: anyDate().addingTimeInterval(600), moisture: nil)]

        XCTAssertEqual(makeSUT(metric: .moisture, samples: samples).xDomain, makeSUT(metric: .light, samples: samples).xDomain)
    }

    func test_xDomain_isNilWithoutSamples() {
        XCTAssertNil(makeSUT(samples: []).xDomain)
    }

    func test_xAxisStride_isSixHoursForDayAndOneDayForWeek() {
        XCTAssertEqual(makeSUT(range: .day).xAxisStride, PlantHistoryAxisStride(component: .hour, count: 6))
        XCTAssertEqual(makeSUT(range: .week).xAxisStride, PlantHistoryAxisStride(component: .day, count: 1))
    }

    func test_xAxisLabel_showsTwoDigitTwentyFourHourForDay() {
        let sut = makeSUT(range: .day)

        XCTAssertEqual(sut.xAxisLabel(for: anyDate()), "08")
        XCTAssertEqual(sut.xAxisLabel(for: anyDate().addingTimeInterval(6 * 3_600)), "14")
        XCTAssertEqual(sut.xAxisLabel(for: anyDate().addingTimeInterval(16 * 3_600)), "00")
    }

    func test_xAxisLabel_showsShortWeekdayForWeek() {
        // 2026-01-01 is a Thursday.
        let sut = makeSUT(range: .week)

        XCTAssertEqual(sut.xAxisLabel(for: anyDate()), "Thu")
        XCTAssertEqual(sut.xAxisLabel(for: anyDate().addingTimeInterval(24 * 3_600)), "Fri")
    }

    func test_xAxisLabel_usesCalendarTimeZone() {
        var plusTwo = utcCalendar()
        plusTwo.timeZone = TimeZone(secondsFromGMT: 2 * 3_600)!

        XCTAssertEqual(makeSUT(range: .day, calendar: plusTwo).xAxisLabel(for: anyDate()), "10")
    }

    func test_yAxisLabel_usesFixedLocale() {
        let sut = makeSUT(metric: .light)

        XCTAssertEqual(sut.yAxisLabel(for: 2_000), "2,000")
        XCTAssertEqual(sut.yAxisLabel(for: 22.5), "22.5")
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

    // MARK: - Private helpers

    private func makeSUT(
        metric: PlantHistoryMetric = .moisture,
        samples: [PlantHistorySample] = [],
        range: PlantHistoryRange = .day,
        calendar: Calendar? = nil
    ) -> PlantHistoryChartViewModel {
        PlantHistoryChartViewModel(metric: metric, samples: samples, range: range, calendar: calendar ?? utcCalendar())
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}
