import Foundation

public enum PlantDeviceAction: Equatable {
    case pairTap
    case paired
    case modeChanged(PlantDeviceMode)
    case openSettings
}
