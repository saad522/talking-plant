import Foundation

/// Display formatting for reading values, with a fixed locale so output is predictable in tests.
public enum PlantReadingFormatter {
    public static let placeholder = "–"
    private static let locale = Locale(identifier: "en_US")

    public static func percent(_ value: Double?) -> String {
        guard let value else { return placeholder }
        return value.formatted(.number.precision(.fractionLength(0)).locale(locale)) + "%"
    }

    public static func lux(_ value: Int?) -> String {
        guard let value else { return placeholder }
        return value.formatted(.number.locale(locale)) + " lx"
    }

    public static func temperature(_ value: Double?) -> String {
        guard let value else { return placeholder }
        return value.formatted(.number.precision(.fractionLength(1)).locale(locale)) + " °C"
    }
}
