import Foundation

/// The raw fields of a Readings packet (`docs/BLE_CONTRACT.md`). No units, no calibration:
/// each feature's mapper applies its own rules.
public struct PlantReadingPacket: Equatable, Sendable {
    public enum Flag: UInt8, Sendable {
        case soil = 0b0001
        case light = 0b0010
        case environment = 0b0100
        case battery = 0b1000
    }

    public let version: UInt8
    public let flags: UInt8
    public let soilMillivolts: UInt16
    public let lux: UInt16
    public let temperatureCenti: Int16
    public let humidityCenti: UInt16
    public let batteryMillivolts: UInt16
    public let sequence: UInt32

    /// Returns `nil` unless `data` is exactly `PlantBluetoothContract.readingLength` bytes.
    public init?(data: Data) {
        guard data.count == PlantBluetoothContract.readingLength else { return nil }
        let bytes = [UInt8](data)
        version = bytes[0]
        flags = bytes[1]
        soilMillivolts = bytes.uint16(at: 2)
        lux = bytes.uint16(at: 4)
        temperatureCenti = Int16(bitPattern: bytes.uint16(at: 6))
        humidityCenti = bytes.uint16(at: 8)
        batteryMillivolts = bytes.uint16(at: 10)
        sequence = bytes.uint32(at: 12)
    }

    public func has(_ flag: Flag) -> Bool {
        flags & flag.rawValue != 0
    }
}

private extension Array where Element == UInt8 {
    func uint16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func uint32(at offset: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { value, index in
            value | UInt32(self[offset + index]) << (8 * index)
        }
    }
}
