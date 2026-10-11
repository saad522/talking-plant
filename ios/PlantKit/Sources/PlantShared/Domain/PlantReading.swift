import Foundation

/// A reading in physical units. Fields whose flag bit is clear are `nil`.
public struct PlantReading: Equatable, Sendable {
    public let moisture: Double?          // %, already calibrated
    public let lux: Int?
    public let temperature: Double?       // °C
    public let humidity: Double?          // %RH
    public let batteryMillivolts: Int?
    public let sequence: UInt32
    /// Phone time when the packet was received. The board has no clock.
    public let receivedAt: Date

    public init(
        moisture: Double?,
        lux: Int?,
        temperature: Double?,
        humidity: Double?,
        batteryMillivolts: Int?,
        sequence: UInt32,
        receivedAt: Date
    ) {
        self.moisture = moisture
        self.lux = lux
        self.temperature = temperature
        self.humidity = humidity
        self.batteryMillivolts = batteryMillivolts
        self.sequence = sequence
        self.receivedAt = receivedAt
    }
}
