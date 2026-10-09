import Foundation
import PlantShared

enum PlantDeviceInfoMapper {
    // Replaced by the Device Info loader's `Error` when the loader is added in M6.
    enum Error: Swift.Error, Equatable {
        case invalidData
    }

    private struct RemoteDeviceInfo {
        private let protocolVersion: UInt8
        private let firmwareMajor: UInt8
        private let firmwareMinor: UInt8
        private let firmwarePatch: UInt8
        private let capabilities: UInt8
        private let intervalSeconds: UInt16

        init?(data: Data) {
            guard data.count == PlantBluetoothContract.deviceInfoLength else { return nil }
            let bytes = [UInt8](data)
            protocolVersion = bytes[0]
            firmwareMajor = bytes[1]
            firmwareMinor = bytes[2]
            firmwarePatch = bytes[3]
            capabilities = bytes[4]
            intervalSeconds = UInt16(bytes[6]) | UInt16(bytes[7]) << 8
        }

        var local: PlantDeviceInfo {
            PlantDeviceInfo(
                protocolVersion: protocolVersion,
                firmwareMajor: firmwareMajor,
                firmwareMinor: firmwareMinor,
                firmwarePatch: firmwarePatch,
                capabilities: PlantDeviceInfo.Capabilities(rawValue: capabilities),
                intervalSeconds: intervalSeconds
            )
        }
    }

    static func map(_ data: Data) throws -> PlantDeviceInfo {
        guard let info = RemoteDeviceInfo(data: data) else {
            throw Error.invalidData
        }

        return info.local
    }
}
