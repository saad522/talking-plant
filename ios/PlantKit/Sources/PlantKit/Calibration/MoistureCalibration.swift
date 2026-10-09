import Foundation

/// Converts soil sensor millivolts to moisture %. Higher millivolts = drier.
public struct MoistureCalibration: Equatable, Sendable {
    /// Placeholder until the real sensor is calibrated. Show "not calibrated" in the UI.
    public static let placeholder = MoistureCalibration(dry: 2400, wet: 1100, isCalibrated: false)

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
