import Foundation
import PlantShared

enum PlantDeviceFormatter {
    /// "Every 30 s", "Every 5 min". Whole minutes are shown as minutes.
    static func interval(seconds: UInt16) -> String {
        if seconds >= 60 && seconds % 60 == 0 {
            return String(format: String.localised(key: "plant.device.interval.minutes"), Int(seconds / 60))
        }
        return String(format: String.localised(key: "plant.device.interval.seconds"), Int(seconds))
    }

    /// "2,450 mV", or "–" when there is no value.
    static func millivolts(_ value: Int?) -> String {
        guard let value else { return PlantReadingFormatter.placeholder }
        return value.formatted(.number.locale(PlantReadingFormatter.locale)) + " mV"
    }

    /// A fixed two-decimal number with a unit, so it matches the serial log digit for digit.
    static func decimal(_ value: Double?, unit: String) -> String {
        guard let value else { return PlantReadingFormatter.placeholder }
        return value.formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(PlantReadingFormatter.locale)) + " " + unit
    }

    /// "0x07"
    static func flags(_ value: UInt8) -> String {
        String(format: "0x%02X", value)
    }

    /// "14:03:15"
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
