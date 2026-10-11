import Foundation

/// Thresholds the health rules judge a plant by.
public struct PlantProfile: Equatable, Sendable {
    public let thirstyMoisture: Double
    public let veryThirstyMoisture: Double
    public let drowningMoisture: Double
    public let drowningDuration: TimeInterval
    public let minimumTemperature: Double
    public let maximumTemperature: Double
    public let minimumHumidity: Double
    public let minimumAverageLux: Double
    public let lightWindow: TimeInterval
    public let minimumLightCoverage: TimeInterval
    public let offlineAfter: TimeInterval
    /// How much history the loader has to give the evaluator.
    public let historyWindow: TimeInterval

    public init(
        thirstyMoisture: Double,
        veryThirstyMoisture: Double,
        drowningMoisture: Double,
        drowningDuration: TimeInterval,
        minimumTemperature: Double,
        maximumTemperature: Double,
        minimumHumidity: Double,
        minimumAverageLux: Double,
        lightWindow: TimeInterval,
        minimumLightCoverage: TimeInterval,
        offlineAfter: TimeInterval,
        historyWindow: TimeInterval
    ) {
        self.thirstyMoisture = thirstyMoisture
        self.veryThirstyMoisture = veryThirstyMoisture
        self.drowningMoisture = drowningMoisture
        self.drowningDuration = drowningDuration
        self.minimumTemperature = minimumTemperature
        self.maximumTemperature = maximumTemperature
        self.minimumHumidity = minimumHumidity
        self.minimumAverageLux = minimumAverageLux
        self.lightWindow = lightWindow
        self.minimumLightCoverage = minimumLightCoverage
        self.offlineAfter = offlineAfter
        self.historyWindow = historyWindow
    }
}

extension PlantProfile {
    private static let hour: TimeInterval = 3_600

    public static let houseplant = PlantProfile(
        thirstyMoisture: 30,
        veryThirstyMoisture: 15,
        drowningMoisture: 90,
        drowningDuration: 48 * hour,
        minimumTemperature: 15,
        maximumTemperature: 30,
        minimumHumidity: 35,
        minimumAverageLux: 200,
        lightWindow: 24 * hour,
        minimumLightCoverage: 18 * hour,
        offlineAfter: 15 * 60,
        // The drowning streak has to start inside the window, so allow one offline gap on top of 48 h.
        historyWindow: 48 * hour + 15 * 60
    )
}
