import Foundation
import PlantShared

public enum PlantHealthEvaluator {
    /// - Parameter readings: The history window, oldest first.
    public static func evaluate(readings: [PlantReading], now: Date, profile: PlantProfile) -> PlantHealth {
        let issues = PlantHealthIssue.allCases.filter { isPresent($0, readings: readings, now: now, profile: profile) }
        let penalty = issues.reduce(0) { $0 + $1.penalty }
        return PlantHealth(score: max(0, 100 - penalty), issues: issues)
    }

    private static func isPresent(
        _ issue: PlantHealthIssue,
        readings: [PlantReading],
        now: Date,
        profile: PlantProfile
    ) -> Bool {
        guard let latest = readings.last else { return issue == .offline }

        switch issue {
        case .offline:
            return now.timeIntervalSince(latest.receivedAt) > profile.offlineAfter
        case .drowning:
            return isDrowning(readings, latest: latest, now: now, profile: profile)
        case .veryThirsty:
            return latest.moisture.map { $0 < profile.veryThirstyMoisture } ?? false
        case .thirsty:
            guard let moisture = latest.moisture else { return false }
            return moisture < profile.thirstyMoisture && moisture >= profile.veryThirstyMoisture
        case .tooHot:
            return latest.temperature.map { $0 > profile.maximumTemperature } ?? false
        case .tooCold:
            return latest.temperature.map { $0 < profile.minimumTemperature } ?? false
        case .tooDark:
            return isTooDark(readings, now: now, profile: profile)
        case .dryAir:
            return latest.humidity.map { $0 < profile.minimumHumidity } ?? false
        }
    }

    /// The latest reading is very wet and so is every reading since `drowningDuration` ago.
    private static func isDrowning(
        _ readings: [PlantReading],
        latest: PlantReading,
        now: Date,
        profile: PlantProfile
    ) -> Bool {
        guard let moisture = latest.moisture, moisture >= profile.drowningMoisture else { return false }

        var streakStart = latest.receivedAt
        for reading in readings.reversed() {
            guard let value = reading.moisture else { continue }
            if value < profile.drowningMoisture { break }
            streakStart = reading.receivedAt
        }
        return now.timeIntervalSince(streakStart) >= profile.drowningDuration
    }

    /// Judged only once the light window is mostly covered, so a fresh install or a dark night doesn't count.
    private static func isTooDark(_ readings: [PlantReading], now: Date, profile: PlantProfile) -> Bool {
        let windowStart = now.addingTimeInterval(-profile.lightWindow)
        let lit = readings.filter { $0.receivedAt >= windowStart && $0.lux != nil }
        guard let oldest = lit.first, now.timeIntervalSince(oldest.receivedAt) >= profile.minimumLightCoverage else {
            return false
        }
        let average = Double(lit.compactMap(\.lux).reduce(0, +)) / Double(lit.count)
        return average < profile.minimumAverageLux
    }
}
