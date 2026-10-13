import PlantShared

public enum PlantDeviceCalibrationError: Error, Equatable, Sendable {
    case missingDry
    case missingWet
    case wetNotBelowDry
    case rangeTooSmall
}

public enum PlantDeviceCalibrationValidator {
    public static let minimumRangeMillivolts = 300
    /// The ESP32-C3 ADC at 12 dB is rated for 0-2500 mV. At or above this the sensor may be saturating.
    public static let adcLimitWarningMillivolts = 2480

    public static func validate(dry: Int?, wet: Int?) -> Result<MoistureCalibration, PlantDeviceCalibrationError> {
        guard let dry else { return .failure(.missingDry) }
        guard let wet else { return .failure(.missingWet) }
        guard wet < dry else { return .failure(.wetNotBelowDry) }
        guard dry - wet >= minimumRangeMillivolts else { return .failure(.rangeTooSmall) }
        guard let calibration = MoistureCalibration(dryMillivolts: dry, wetMillivolts: wet) else {
            return .failure(.wetNotBelowDry)
        }
        return .success(calibration)
    }

    public static func isNearADCLimit(dry: Int) -> Bool {
        dry >= adcLimitWarningMillivolts
    }
}
