import Foundation

/// Minimum, average and maximum of each sensor over a period.
public struct PlantHistorySummary: Equatable, Sendable {
    public enum Period: Equatable, Sendable {
        case day
        case week
    }

    public struct Statistics: Equatable, Sendable {
        public let minimum: Double
        public let average: Double
        public let maximum: Double

        public init(minimum: Double, average: Double, maximum: Double) {
            self.minimum = minimum
            self.average = average
            self.maximum = maximum
        }
    }

    public let period: Period
    public let readingCount: Int
    /// Each is nil when no reading in the period had that value.
    public let moisture: Statistics?
    public let lux: Statistics?
    public let temperature: Statistics?
    public let humidity: Statistics?

    public init(
        period: Period,
        readingCount: Int,
        moisture: Statistics?,
        lux: Statistics?,
        temperature: Statistics?,
        humidity: Statistics?
    ) {
        self.period = period
        self.readingCount = readingCount
        self.moisture = moisture
        self.lux = lux
        self.temperature = temperature
        self.humidity = humidity
    }
}
