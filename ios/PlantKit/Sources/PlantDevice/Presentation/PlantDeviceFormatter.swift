import Foundation

enum PlantDeviceFormatter {
    /// "Every 30 s", "Every 5 min". Whole minutes are shown as minutes.
    static func interval(seconds: UInt16) -> String {
        if seconds >= 60 && seconds % 60 == 0 {
            return String(format: String.localised(key: "plant.device.interval.minutes"), Int(seconds / 60))
        }
        return String(format: String.localised(key: "plant.device.interval.seconds"), Int(seconds))
    }
}
