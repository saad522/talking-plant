import Foundation

/// A Readings packet before calibration. Fields are `nil` when the packet's flag bit is clear.
public struct PlantDeviceRawReading: Equatable, Sendable {
    public let soilMillivolts: Int?
    public let lux: Int?
    public let temperature: Double?
    public let humidity: Double?
    public let flags: UInt8
    public let sequence: UInt32
    public let receivedAt: Date

    public init(
        soilMillivolts: Int?,
        lux: Int?,
        temperature: Double?,
        humidity: Double?,
        flags: UInt8,
        sequence: UInt32,
        receivedAt: Date
    ) {
        self.soilMillivolts = soilMillivolts
        self.lux = lux
        self.temperature = temperature
        self.humidity = humidity
        self.flags = flags
        self.sequence = sequence
        self.receivedAt = receivedAt
    }
}
