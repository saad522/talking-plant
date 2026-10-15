import PlantDevice

/// What the settings screen's controls do. The composer builds it, so the view stays free of feedback and view model calls.
struct PlantDeviceControls {
    let modeSelect: (PlantDeviceMode) -> Void
    let openSettings: () -> Void
    let readNow: () -> Void
    let calibration: () -> Void
    let pair: () -> Void
    let forget: () -> Void
    let clearHistory: () -> Void
    let clearHistoryConfirm: () -> Void
    let clearHistoryCancel: () -> Void
}

/// What the calibration screen's controls do.
struct PlantDeviceCalibrationControls {
    let capture: (PlantDeviceCalibrationPoint) -> Void
    let save: () -> Void
    let reset: () -> Void
}
