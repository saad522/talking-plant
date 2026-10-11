import Foundation

/// Display formatting for reading values, with a fixed locale so output is predictable in tests.
public enum PlantReadingFormatter {
    public static let placeholder = "–"
    public static let locale = Locale(identifier: "en_US")

    public static func percent(_ value: Double?) -> String {
        guard let value else { return placeholder }
        return value.formatted(.number.precision(.fractionLength(0)).locale(locale)) + "%"
    }

    /// A plain number, e.g. for chart axis labels.
    public static func number(_ value: Double) -> String {
        value.formatted(.number.locale(locale))
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
