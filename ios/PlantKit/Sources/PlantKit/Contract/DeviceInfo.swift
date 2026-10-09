import Foundation

/// Decoded 8-byte Device Info characteristic.
public struct DeviceInfo: Equatable, Sendable {
    public struct Capabilities: OptionSet, Equatable, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let pump = Capabilities(rawValue: 1 << 0)
        public static let display = Capabilities(rawValue: 1 << 1)
        public static let batterySense = Capabilities(rawValue: 1 << 2)
    }

    public let protocolVersion: UInt8
    public let firmwareMajor: UInt8
    public let firmwareMinor: UInt8
    public let firmwarePatch: UInt8
    public let capabilities: Capabilities
    public let intervalSeconds: UInt16

    public var firmwareVersion: String { "\(firmwareMajor).\(firmwareMinor).\(firmwarePatch)" }

    /// Throws `PlantContractError.wrongLength` when the length is not 8.
    public init(data: Data) throws {
        let bytes = [UInt8](data)
        guard bytes.count == PlantContract.deviceInfoLength else {
            throw PlantContractError.wrongLength(expected: PlantContract.deviceInfoLength, actual: bytes.count)
        }
        protocolVersion = bytes[0]
        firmwareMajor = bytes[1]
        firmwareMinor = bytes[2]
        firmwarePatch = bytes[3]
        capabilities = Capabilities(rawValue: bytes[4])
        intervalSeconds = bytes.uint16LE(at: 6)
    }
}
