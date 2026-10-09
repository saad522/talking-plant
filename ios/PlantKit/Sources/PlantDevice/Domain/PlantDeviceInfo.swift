import Foundation

/// Device Info characteristic in domain form.
public struct PlantDeviceInfo: Equatable, Sendable {
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

    public init(
        protocolVersion: UInt8,
        firmwareMajor: UInt8,
        firmwareMinor: UInt8,
        firmwarePatch: UInt8,
        capabilities: Capabilities,
        intervalSeconds: UInt16
    ) {
        self.protocolVersion = protocolVersion
        self.firmwareMajor = firmwareMajor
        self.firmwareMinor = firmwareMinor
        self.firmwarePatch = firmwarePatch
        self.capabilities = capabilities
        self.intervalSeconds = intervalSeconds
    }
}
