import PlantShared

@MainActor
public final class LocalMoistureCalibrationLoader {
    static let dryKey = "plant.device.calibration.dryMillivolts"
    static let wetKey = "plant.device.calibration.wetMillivolts"

    private let defaults: DefaultsClient

    public init(defaults: DefaultsClient) {
        self.defaults = defaults
    }

    /// The saved calibration, or `.placeholder` when nothing valid is saved.
    public func load() -> MoistureCalibration {
        guard let dry = defaults.retrieve(forKey: Self.dryKey),
              let wet = defaults.retrieve(forKey: Self.wetKey),
              let calibration = MoistureCalibration(dryMillivolts: Int(dry), wetMillivolts: Int(wet)),
              wet > 0 else { return .placeholder }
        return calibration
    }

    public func save(_ calibration: MoistureCalibration) {
        defaults.set(Double(calibration.dryMillivolts), forKey: Self.dryKey)
        defaults.set(Double(calibration.wetMillivolts), forKey: Self.wetKey)
    }

    /// `DefaultsClient` can't remove a key, so resetting saves zeros, which `load()` ignores.
    public func reset() {
        defaults.set(0.0, forKey: Self.dryKey)
        defaults.set(0.0, forKey: Self.wetKey)
    }
}
