import PlantShared

public struct PlantDeviceCalibrationStatusViewModel: Equatable {
    public let status: String
    public let dry: String
    public let wet: String
    public let isCalibrated: Bool

    public init(calibration: MoistureCalibration) {
        isCalibrated = calibration.isCalibrated
        status = String.localised(key: calibration.isCalibrated
            ? "plant.device.calibration.status.calibrated"
            : "plant.device.calibration.status.notCalibrated")
        dry = PlantDeviceFormatter.millivolts(calibration.dryMillivolts)
        wet = PlantDeviceFormatter.millivolts(calibration.wetMillivolts)
    }
}
