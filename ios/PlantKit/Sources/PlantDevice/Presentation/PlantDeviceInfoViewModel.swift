import Foundation

public final class PlantDeviceInfoViewModel: Equatable {
    public let firmware: String
    public let interval: String

    public init(info: PlantDeviceInfo) {
        firmware = info.firmwareVersion
        interval = PlantDeviceFormatter.interval(seconds: info.intervalSeconds)
    }

    public static func == (lhs: PlantDeviceInfoViewModel, rhs: PlantDeviceInfoViewModel) -> Bool {
        lhs.firmware == rhs.firmware && lhs.interval == rhs.interval
    }
}
