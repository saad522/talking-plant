import Foundation
import PlantShared

@MainActor
public final class PlantDeviceViewModel {
    public typealias Observer<T> = (T) -> Void

    public struct ModeOption: Equatable {
        public let mode: PlantDeviceMode
        public let label: String
    }

    private let connectionLoader: PlantDeviceConnectionLoader
    private let pairingLoader: PlantDevicePairingLoader
    private let infoLoader: PlantDeviceInfoLoader
    private let calibrationLoader: LocalMoistureCalibrationLoader
    private let rawReadingLoader: PlantDeviceRawReadingLoader
    private let commandSender: PlantDeviceCommandSender
    private let settings: PlantDeviceSettings
    private let actionHandler: (PlantDeviceAction) -> Void
    private var appeared: Bool = false
    private var wasConnected: Bool = false

    public let title: String = String.localised(key: "plant.device.title")
    public let modeSectionLabel: String = String.localised(key: "plant.device.mode.section")
    public let modes: [ModeOption] = [
        ModeOption(mode: .simulated, label: String.localised(key: "plant.device.mode.simulated.label")),
        ModeOption(mode: .sensor, label: String.localised(key: "plant.device.mode.sensor.label"))
    ]
    public let sensorSectionLabel: String = String.localised(key: "plant.device.sensor.section")
    public let statusLabel: String = String.localised(key: "plant.device.status.label")
    public let pairedLabel: String = String.localised(key: "plant.device.paired.label")
    public let noSensorPairedLabel: String = String.localised(key: "plant.device.paired.none")
    public let firmwareLabel: String = String.localised(key: "plant.device.firmware.label")
    public let intervalLabel: String = String.localised(key: "plant.device.interval.label")
    public let readNowLabel: String = String.localised(key: "plant.device.readNow.label")
    public let pairLabel: String = String.localised(key: "plant.device.pair.label")
    public let changeLabel: String = String.localised(key: "plant.device.change.label")
    public let forgetLabel: String = String.localised(key: "plant.device.forget.label")
    public let openSettingsLabel: String = String.localised(key: "plant.device.openSettings.label")
    public let calibrationLabel: String = String.localised(key: "plant.device.calibration.title")
    public let rawSectionLabel: String = String.localised(key: "plant.device.raw.section")
    public let rawSoilLabel: String = String.localised(key: "plant.device.raw.soil.label")
    public let rawLightLabel: String = String.localised(key: "plant.device.raw.light.label")
    public let rawTemperatureLabel: String = String.localised(key: "plant.device.raw.temperature.label")
    public let rawHumidityLabel: String = String.localised(key: "plant.device.raw.humidity.label")
    public let rawFlagsLabel: String = String.localised(key: "plant.device.raw.flags.label")
    public let rawSequenceLabel: String = String.localised(key: "plant.device.raw.sequence.label")
    public let rawReceivedLabel: String = String.localised(key: "plant.device.raw.received.label")
    public let clearHistoryLabel: String = String.localised(key: "plant.device.clearHistory.label")
    public let clearHistoryTitle: String = String.localised(key: "plant.device.clearHistory.title")
    public let clearHistoryMessage: String = String.localised(key: "plant.device.clearHistory.message")
    public let clearHistoryConfirmLabel: String = String.localised(key: "plant.device.clearHistory.confirm")
    public let clearHistoryCancelLabel: String = String.localised(key: "plant.device.clearHistory.cancel")

    public var loadedMode: Observer<PlantDeviceMode>?
    public var loadedConnection: Observer<PlantDeviceConnectionViewModel>?
    public var loadedPairedDevice: Observer<PlantPairedDevice?>?
    public var loadedInfo: Observer<PlantDeviceInfoViewModel>?
    /// "Calibrated" or "Not calibrated".
    public var loadedCalibrationStatus: Observer<String>?
    public var loadedRawReading: Observer<PlantDeviceRawReadingViewModel>?
    /// The message to show, or `nil` to clear it.
    public var loadedCommandError: Observer<String?>?

    public init(
        connectionLoader: PlantDeviceConnectionLoader,
        pairingLoader: PlantDevicePairingLoader,
        infoLoader: PlantDeviceInfoLoader,
        calibrationLoader: LocalMoistureCalibrationLoader,
        rawReadingLoader: PlantDeviceRawReadingLoader,
        commandSender: PlantDeviceCommandSender,
        settings: PlantDeviceSettings,
        actionHandler: @escaping (PlantDeviceAction) -> Void
    ) {
        self.connectionLoader = connectionLoader
        self.pairingLoader = pairingLoader
        self.infoLoader = infoLoader
        self.calibrationLoader = calibrationLoader
        self.rawReadingLoader = rawReadingLoader
        self.commandSender = commandSender
        self.settings = settings
        self.actionHandler = actionHandler
    }

    public func appear() {
        loadedCalibrationStatus?(PlantDeviceCalibrationStatusViewModel(calibration: calibrationLoader.load()).status)
        guard appeared == false else { return }
        appeared = true
        loadedMode?(settings.loadMode())
        connectionLoader.subscribe { [weak self] connection in
            self?.update(connection)
        }
        pairingLoader.subscribe { [weak self] device in
            self?.loadedPairedDevice?(device)
        }
        rawReadingLoader.subscribe { [weak self] result in
            self?.receive(result)
        }
    }

    public func modeSelect(_ mode: PlantDeviceMode) {
        guard mode != settings.loadMode() else { return }
        settings.saveMode(mode)
        loadedMode?(mode)
        actionHandler(.modeChanged(mode))
    }

    public func pairTap() {
        actionHandler(.pairTap)
    }

    public func forgetTap() {
        pairingLoader.forget()
    }

    public func readNowTap() {
        commandSender.send(.readNow) { [weak self] error in
            self?.loadedCommandError?(error == nil ? nil : String.localised(key: "plant.device.command.error"))
        }
    }

    public func calibrationTap() {
        actionHandler(.calibrationTap)
    }

    public func clearHistoryConfirmTap() {
        actionHandler(.clearSensorHistory)
    }

    public func openSettingsTap() {
        actionHandler(.openSettings)
    }

    private func update(_ connection: PlantConnection) {
        loadedConnection?(PlantDeviceConnectionViewModel(connection: connection))
        let isConnected = connection == .connected
        defer { wasConnected = isConnected }
        guard isConnected, wasConnected == false else { return }
        infoLoader.load { [weak self] result in
            if case .success(let info) = result {
                self?.loadedInfo?(PlantDeviceInfoViewModel(info: info))
            }
        }
        rawReadingLoader.load { [weak self] result in
            self?.receive(result)
        }
    }

    private func receive(_ result: PlantDeviceRawReadingLoader.Result) {
        if case .success(let reading) = result {
            loadedRawReading?(PlantDeviceRawReadingViewModel(reading: reading))
        }
    }
}
