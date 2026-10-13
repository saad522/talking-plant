import Foundation

public enum PlantDeviceAction: Equatable {
    case pairTap
    case paired
    case modeChanged(PlantDeviceMode)
    case calibrationTap
    case openSettings
    /// DEBUG only: the app deletes the sensor history.
    case clearSensorHistory
}
