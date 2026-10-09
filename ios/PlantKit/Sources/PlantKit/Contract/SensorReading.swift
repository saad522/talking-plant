import Foundation

/// A reading in physical units. Fields whose flag bit is clear are `nil`.
public struct SensorReading: Equatable, Sendable {
    /// Phone time when the packet was received. The board has no clock.
    public let receivedAt: Date
    public let sequence: UInt32
    public let soilMillivolts: Int?
    public let lux: Int?
    public let temperatureCelsius: Double?
    public let humidityPercent: Double?
    public let batteryMillivolts: Int?

    public init(packet: ReadingPacket, receivedAt: Date) {
        let flags = packet.flags
        self.receivedAt = receivedAt
        sequence = packet.sequence
        soilMillivolts = flags.contains(.soilValid) ? Int(packet.soilMillivolts) : nil
        lux = flags.contains(.lightValid) ? Int(packet.lux) : nil
        temperatureCelsius = flags.contains(.envValid) ? Double(packet.temperatureCenti) / 100 : nil
        humidityPercent = flags.contains(.envValid) ? Double(packet.humidityCenti) / 100 : nil
        batteryMillivolts = flags.contains(.batteryValid) ? Int(packet.batteryMillivolts) : nil
    }
}
