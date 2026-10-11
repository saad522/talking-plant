import PlantShared
import XCTest
@testable import PlantMonitor

@MainActor
final class PlantHealthEvaluatorTests: PlantMonitorXCTestCase {
    private let hour: TimeInterval = 3_600
    private let profile = PlantProfile.houseplant

    // MARK: - Healthy and offline

    func test_evaluate_isHappyAndFullScoreForHealthyReading() {
        let health = evaluate([reading(ago: 60)])

        XCTAssertEqual(health, PlantHealth(score: 100, issues: []))
        XCTAssertEqual(health.mood, .happy)
    }

    func test_evaluate_isOfflineWithoutReadings() {
        let health = evaluate([])

        XCTAssertEqual(health.issues, [.offline])
        XCTAssertEqual(health.mood, .offline)
    }

    func test_evaluate_isOfflineOnlyAfterOfflineInterval() {
        XCTAssertEqual(evaluate([reading(ago: profile.offlineAfter)]).issues, [])
        XCTAssertEqual(evaluate([reading(ago: profile.offlineAfter + 1)]).issues, [.offline])
    }

    func test_evaluate_offlineKeepsScoreOfLastKnownCondition() {
        let health = evaluate([reading(moisture: 20, ago: hour)])

        XCTAssertEqual(health.issues, [.offline, .thirsty])
        XCTAssertEqual(health.score, 70)
    }

    // MARK: - Moisture

    func test_evaluate_thirstyBelowThirstyThresholdOnly() {
        XCTAssertEqual(evaluate([reading(moisture: 30, ago: 60)]).issues, [])
        XCTAssertEqual(evaluate([reading(moisture: 29.9, ago: 60)]).issues, [.thirsty])
    }

    func test_evaluate_veryThirstyBelowVeryThirstyThresholdOnly() {
        XCTAssertEqual(evaluate([reading(moisture: 15, ago: 60)]).issues, [.thirsty])
        XCTAssertEqual(evaluate([reading(moisture: 14.9, ago: 60)]).issues, [.veryThirsty])
    }

    func test_evaluate_usesLatestReadingForMoisture() {
        let health = evaluate([reading(moisture: 5, ago: 600), reading(moisture: 60, ago: 60)])

        XCTAssertEqual(health.issues, [])
    }

    // MARK: - Drowning

    func test_evaluate_isNotDrowningWhenWetStreakIsTooShort() {
        let readings = wetReadings(from: 47 * hour)

        XCTAssertEqual(evaluate(readings).issues, [])
    }

    func test_evaluate_isDrowningWhenWetStreakIsLongEnough() {
        let readings = wetReadings(from: 48 * hour)

        XCTAssertEqual(evaluate(readings).issues, [.drowning])
    }

    func test_evaluate_isNotDrowningWhenStreakWasInterrupted() {
        let readings = [reading(moisture: 95, ago: 50 * hour), reading(moisture: 60, ago: 10 * hour)]
            + wetReadings(from: 9 * hour)

        XCTAssertEqual(evaluate(readings).issues, [])
    }

    func test_evaluate_streakStartsAfterLastDryReading() {
        let readings = [reading(moisture: 60, ago: 60 * hour)] + wetReadings(from: 49 * hour)

        XCTAssertEqual(evaluate(readings).issues, [.drowning])
    }

    func test_evaluate_isNotDrowningWhenLatestIsBelowThreshold() {
        let readings = wetReadings(from: 49 * hour, until: 2 * hour) + [reading(moisture: 89.9, ago: 60)]

        XCTAssertEqual(evaluate(readings).issues, [])
    }

    func test_evaluate_drowningStreakSkipsMissingMoisture() {
        let readings = [reading(moisture: 95, ago: 49 * hour), reading(moisture: nil, ago: 20 * hour), reading(moisture: 95, ago: 60)]

        XCTAssertEqual(evaluate(readings).issues, [.drowning])
    }

    // MARK: - Temperature and humidity

    func test_evaluate_tooHotAboveMaximumOnly() {
        XCTAssertEqual(evaluate([reading(temperature: 30, ago: 60)]).issues, [])
        XCTAssertEqual(evaluate([reading(temperature: 30.1, ago: 60)]).issues, [.tooHot])
    }

    func test_evaluate_tooColdBelowMinimumOnly() {
        XCTAssertEqual(evaluate([reading(temperature: 15, ago: 60)]).issues, [])
        XCTAssertEqual(evaluate([reading(temperature: 14.9, ago: 60)]).issues, [.tooCold])
    }

    func test_evaluate_dryAirBelowMinimumHumidityOnly() {
        XCTAssertEqual(evaluate([reading(humidity: 35, ago: 60)]).issues, [])
        XCTAssertEqual(evaluate([reading(humidity: 34.9, ago: 60)]).issues, [.dryAir])
    }

    func test_evaluate_skipsRulesWithMissingValues() {
        let health = evaluate([reading(moisture: nil, lux: nil, temperature: nil, humidity: nil, ago: 60)])

        XCTAssertEqual(health, PlantHealth(score: 100, issues: []))
    }

    // MARK: - Light

    func test_evaluate_isTooDarkWhenAverageIsLowWithEnoughCoverage() {
        let readings = lightReadings(lux: 100, from: 20 * hour)

        XCTAssertEqual(evaluate(readings).issues, [.tooDark])
    }

    func test_evaluate_isNotTooDarkWhenAverageIsEnough() {
        let readings = lightReadings(lux: 200, from: 20 * hour)

        XCTAssertEqual(evaluate(readings).issues, [])
    }

    func test_evaluate_isNotTooDarkWithTooLittleCoverage() {
        let readings = lightReadings(lux: 0, from: 17 * hour)

        XCTAssertEqual(evaluate(readings).issues, [])
    }

    func test_evaluate_darkNightAloneIsNotTooDark() {
        let night = lightReadings(lux: 0, from: 8 * hour)
        let day = lightReadings(lux: 800, from: 24 * hour, until: 8 * hour)

        XCTAssertEqual(evaluate(day + night).issues, [])
    }

    func test_evaluate_ignoresReadingsOlderThanLightWindow() {
        let old = lightReadings(lux: 0, from: 40 * hour, until: 25 * hour)
        let recent = lightReadings(lux: 800, from: 20 * hour)

        XCTAssertEqual(evaluate(old + recent).issues, [])
    }

    // MARK: - Priority and score

    func test_evaluate_sortsIssuesByPriority() {
        let readings = lightReadings(lux: 0, from: 20 * hour, moisture: 10, temperature: 35, humidity: 10)

        XCTAssertEqual(evaluate(readings).issues, [.veryThirsty, .tooHot, .tooDark, .dryAir])
    }

    func test_evaluate_moodFollowsPriorityForEveryPair() {
        let ordered = PlantHealthIssue.allCases

        for (index, higher) in ordered.enumerated() {
            for lower in ordered[(index + 1)...] {
                XCTAssertEqual(PlantHealth(score: 0, issues: [higher, lower]).mood, higher.mood, "\(higher) over \(lower)")
            }
        }
    }

    func test_evaluate_priorityOrderIsOfflineDrowningVeryThirstyHotColdThirstyDarkDry() {
        XCTAssertEqual(PlantHealthIssue.allCases, [.offline, .drowning, .veryThirsty, .tooHot, .tooCold, .thirsty, .tooDark, .dryAir])
    }

    func test_evaluate_mapsEveryIssueToItsMood() {
        let moods = PlantHealthIssue.allCases.map(\.mood)

        XCTAssertEqual(moods, [.offline, .drowning, .veryThirsty, .tooHot, .tooCold, .thirsty, .tooDark, .dryAir])
    }

    func test_evaluate_subtractsPenaltiesFromScore() {
        XCTAssertEqual(evaluate([reading(moisture: 20, ago: 60)]).score, 70)
        XCTAssertEqual(evaluate([reading(moisture: 10, ago: 60)]).score, 40)
        XCTAssertEqual(evaluate([reading(temperature: 35, ago: 60)]).score, 60)
        XCTAssertEqual(evaluate([reading(temperature: 5, ago: 60)]).score, 60)
        XCTAssertEqual(evaluate([reading(humidity: 10, ago: 60)]).score, 85)
        XCTAssertEqual(evaluate(lightReadings(lux: 0, from: 20 * hour)).score, 75)
        XCTAssertEqual(evaluate(wetReadings(from: 48 * hour)).score, 40)
    }

    func test_evaluate_scoreFloorsAtZero() {
        let health = evaluate([reading(moisture: 5, temperature: 40, humidity: 10, ago: 60)])

        XCTAssertEqual(health.issues, [.veryThirsty, .tooHot, .dryAir])
        XCTAssertEqual(health.score, 0)
    }

    // MARK: - Private helpers

    private func now() -> Date {
        Date(timeIntervalSince1970: 10_000_000)
    }

    private func evaluate(_ readings: [PlantReading]) -> PlantHealth {
        PlantHealthEvaluator.evaluate(readings: readings, now: now(), profile: profile)
    }

    private func reading(
        moisture: Double? = 50,
        lux: Int? = 1_000,
        temperature: Double? = 23,
        humidity: Double? = 55,
        ago: TimeInterval
    ) -> PlantReading {
        makeReading(
            moisture: moisture,
            lux: lux,
            temperature: temperature,
            humidity: humidity,
            receivedAt: now().addingTimeInterval(-ago)
        )
    }

    /// Hourly readings from `start` seconds ago until `end` seconds ago, oldest first, plus one a minute ago.
    private func hourly(
        from start: TimeInterval,
        until end: TimeInterval = 0,
        make: (TimeInterval) -> PlantReading
    ) -> [PlantReading] {
        var offsets = Array(stride(from: start, through: end, by: -hour))
        if end == 0 { offsets.append(60) }
        return offsets.map(make)
    }

    private func wetReadings(from start: TimeInterval, until end: TimeInterval = 0) -> [PlantReading] {
        hourly(from: start, until: end) { reading(moisture: 95, ago: $0) }
    }

    private func lightReadings(
        lux: Int,
        from start: TimeInterval,
        until end: TimeInterval = 0,
        moisture: Double = 50,
        temperature: Double = 23,
        humidity: Double = 55
    ) -> [PlantReading] {
        hourly(from: start, until: end) {
            reading(moisture: moisture, lux: lux, temperature: temperature, humidity: humidity, ago: $0)
        }
    }
}
