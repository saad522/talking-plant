import Foundation

/// Converts soil sensor millivolts to moisture %. Higher millivolts = drier.
public struct MoistureCalibration: Equatable, Sendable {
    /// Typical values until the user calibrates their own sensor. Show "not calibrated" in the UI.
    /// Dry 2450 mV: capacitive soil sensor v1.2 manuals give about 2.5 V in open air, and the
    /// ESP32-C3 ADC at 12 dB is rated for 0-2500 mV (ESP-IDF docs), so we stay just inside it.
    /// Wet 1050 mV: the same manuals give about 1.0 V fully submerged, plus a small margin.
    /// No datasheet confirms these. They get replaced by values measured on our sensor.
    public static let placeholder = MoistureCalibration(dry: 2450, wet: 1050, isCalibrated: false)

    public let dryMillivolts: Int
    public let wetMillivolts: Int
    public let isCalibrated: Bool

    /// Returns `nil` unless `dryMillivolts > wetMillivolts`.
    public init?(dryMillivolts: Int, wetMillivolts: Int) {
        guard dryMillivolts > wetMillivolts else { return nil }
        self.init(dry: dryMillivolts, wet: wetMillivolts, isCalibrated: true)
    }

    private init(dry: Int, wet: Int, isCalibrated: Bool) {
        dryMillivolts = dry
        wetMillivolts = wet
        self.isCalibrated = isCalibrated
    }

    /// `clamp((dry - soil) / (dry - wet) * 100, 0, 100)`
    public func moisturePercent(soilMillivolts: Int) -> Double {
        let percent = Double(dryMillivolts - soilMillivolts) / Double(dryMillivolts - wetMillivolts) * 100
        return min(max(percent, 0), 100)
    }
}
