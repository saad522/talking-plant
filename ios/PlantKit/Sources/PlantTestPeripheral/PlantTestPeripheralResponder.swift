#if DEBUG
import Foundation

/// What the test peripheral answers and does, per `docs/BLE_CONTRACT.md`. Mirrors the firmware's
/// `PlantCommandParser` and `PlantDeviceInfoEncoder`. No CoreBluetooth, so it runs on macOS.
public struct PlantTestPeripheralResponder: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case readNow
        case setInterval(seconds: UInt16)
        /// Unknown opcode, too short, or a pump command (this peripheral has no pump).
        case ignored
    }

    public static let defaultIntervalSeconds: UInt16 = 30
    public static let intervalRange: ClosedRange<UInt16> = 10...3_600
    public static let firmwareVersion: (major: UInt8, minor: UInt8, patch: UInt8) = (0, 1, 0)

    private enum Opcode {
        static let readNow: UInt8 = 0x01
        static let setInterval: UInt8 = 0x02
    }

    public private(set) var intervalSeconds: UInt16

    public init(intervalSeconds: UInt16 = PlantTestPeripheralResponder.defaultIntervalSeconds) {
        self.intervalSeconds = intervalSeconds
    }

    /// The 8-byte Device Info for firmware 0.1.0, no capabilities and the current interval.
    public var deviceInfo: Data {
        let firmware = Self.firmwareVersion
        return Data([
            1, firmware.major, firmware.minor, firmware.patch, 0, 0,
            UInt8(intervalSeconds & 0xFF), UInt8(intervalSeconds >> 8)
        ])
    }

    public mutating func handle(command data: Data) -> Effect {
        let bytes = [UInt8](data)
        switch bytes.first {
        case Opcode.readNow:
            return .readNow
        case Opcode.setInterval where bytes.count >= 3:
            let requested = UInt16(bytes[1]) | UInt16(bytes[2]) << 8
            intervalSeconds = min(max(requested, Self.intervalRange.lowerBound), Self.intervalRange.upperBound)
            return .setInterval(seconds: intervalSeconds)
        default:
            return .ignored
        }
    }
}
#endif
