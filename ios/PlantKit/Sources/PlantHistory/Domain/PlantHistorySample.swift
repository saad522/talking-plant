import Foundation

/// Averages of the readings in one time bucket. A value is `nil` when no reading in the
/// bucket had it.
public struct PlantHistorySample: Equatable, Sendable {
    /// Start of the bucket.
    public let date: Date
    public let moisture: Double?          // %
    public let lux: Double?
    public let temperature: Double?       // °C
    public let humidity: Double?          // %RH

    public init(date: Date, moisture: Double?, lux: Double?, temperature: Double?, humidity: Double?) {
        self.date = date
        self.moisture = moisture
        self.lux = lux
        self.temperature = temperature
        self.humidity = humidity
    }
}
