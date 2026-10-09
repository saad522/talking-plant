import Foundation

/// Raw 16-byte Readings packet, decoded field by field with no unit conversion.
public struct ReadingPacket: Equatable, Sendable {
    public struct Flags: OptionSet, Equatable, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let soilValid = Flags(rawValue: 1 << 0)
        public static let lightValid = Flags(rawValue: 1 << 1)
        public static let envValid = Flags(rawValue: 1 << 2)
        public static let batteryValid = Flags(rawValue: 1 << 3)
    }

    public let version: UInt8
    public let flags: Flags
    public let soilMillivolts: UInt16
    public let lux: UInt16
    public let temperatureCenti: Int16
    public let humidityCenti: UInt16
    public let batteryMillivolts: UInt16
    public let sequence: UInt32

    /// Throws `PlantContractError` when the length is not 16 or the version is not 1.
    public init(data: Data) throws {
        let bytes = [UInt8](data)
        guard bytes.count == PlantContract.readingPacketLength else {
            throw PlantContractError.wrongLength(expected: PlantContract.readingPacketLength, actual: bytes.count)
        }
        guard bytes[0] == PlantContract.version else {
            throw PlantContractError.unsupportedVersion(bytes[0])
        }
        version = bytes[0]
        flags = Flags(rawValue: bytes[1])
        soilMillivolts = bytes.uint16LE(at: 2)
        lux = bytes.uint16LE(at: 4)
        temperatureCenti = bytes.int16LE(at: 6)
        humidityCenti = bytes.uint16LE(at: 8)
        batteryMillivolts = bytes.uint16LE(at: 10)
        sequence = bytes.uint32LE(at: 12)
    }
}
