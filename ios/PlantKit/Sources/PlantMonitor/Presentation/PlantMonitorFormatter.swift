import Foundation

enum PlantMonitorFormatter {
    static let placeholder = "–"
    private static let locale = Locale(identifier: "en_US")

    static func percent(_ value: Double?) -> String {
        guard let value else { return placeholder }
        return value.formatted(.number.precision(.fractionLength(0)).locale(locale)) + "%"
    }

    static func lux(_ value: Int?) -> String {
        guard let value else { return placeholder }
        return value.formatted(.number.locale(locale)) + " lx"
    }

    static func temperature(_ value: Double?) -> String {
        guard let value else { return placeholder }
        return value.formatted(.number.precision(.fractionLength(1)).locale(locale)) + " °C"
    }
}
