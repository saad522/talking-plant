import PlantDevice
import SwiftUI

@MainActor
public enum PlantDeviceUIComposer {
    public static func composed(
        connectionLoader: PlantDeviceConnectionLoader,
        pairingLoader: PlantDevicePairingLoader,
        infoLoader: PlantDeviceInfoLoader,
        calibrationLoader: LocalMoistureCalibrationLoader,
        rawReadingLoader: PlantDeviceRawReadingLoader,
        commandSender: PlantDeviceCommandSender,
        settings: PlantDeviceSettings,
        showsRawReading: Bool = false,
        actionHandler: @escaping (PlantDeviceAction) -> Void
    ) -> PlantDeviceView {
        let store = PlantDeviceStore()
        let viewModel = PlantDeviceViewModel(
            connectionLoader: connectionLoader,
            pairingLoader: pairingLoader,
            infoLoader: infoLoader,
            calibrationLoader: calibrationLoader,
            rawReadingLoader: rawReadingLoader,
            commandSender: commandSender,
            settings: settings,
            actionHandler: actionHandler
        )

        viewModel.loadedMode = { [weak store] mode in
            store?.mode = mode
        }

        viewModel.loadedConnection = { [weak store] connection in
            store?.connection = connection
            if connection.isConnected == false {
                store?.info = nil
                store?.commandError = nil
            }
        }

        viewModel.loadedPairedDevice = { [weak store] device in
            store?.pairedName = device?.name
        }

        viewModel.loadedInfo = { [weak store] info in
            store?.info = info
        }

        viewModel.loadedCommandError = { [weak store] message in
            store?.commandError = message
        }

        viewModel.loadedCalibrationStatus = { [weak store] status in
            store?.calibrationStatus = status
        }

        viewModel.loadedRawReading = { [weak store] reading in
            store?.rawReading = reading
        }

        return PlantDeviceView(store: store, viewModel: viewModel, showsRawReading: showsRawReading)
    }

    public static func composedCalibration(
        calibrationLoader: LocalMoistureCalibrationLoader,
        rawReadingLoader: PlantDeviceRawReadingLoader,
        connectionLoader: PlantDeviceConnectionLoader,
        commandSender: PlantDeviceCommandSender,
        schedule: @escaping PlantDeviceCalibrationViewModel.Schedule
    ) -> PlantDeviceCalibrationView {
        let store = PlantDeviceCalibrationStore()
        let viewModel = PlantDeviceCalibrationViewModel(
            calibrationLoader: calibrationLoader,
            rawReadingLoader: rawReadingLoader,
            connectionLoader: connectionLoader,
            commandSender: commandSender,
            schedule: schedule
        )

        viewModel.loadedStatus = { [weak store] status in
            store?.status = status
        }

        viewModel.loadedLiveSoil = { [weak store] soil in
            store?.liveSoil = soil
        }

        viewModel.loadedDraft = { [weak store] draft in
            switch draft.point {
            case .dry: store?.dryDraft = draft.text
            case .wet: store?.wetDraft = draft.text
            }
        }

        viewModel.loadedCapturing = { [weak store] point in
            store?.capturing = point
        }

        viewModel.loadedCanCapture = { [weak store] canCapture in
            store?.canCapture = canCapture
        }

        viewModel.loadedCanSave = { [weak store] canSave in
            store?.canSave = canSave
        }

        viewModel.loadedMessage = { [weak store] message in
            store?.message = message
        }

        viewModel.loadedWarning = { [weak store] warning in
            store?.warning = warning
        }

        return PlantDeviceCalibrationView(store: store, viewModel: viewModel)
    }

    public static func composedPicker(
        scanLoader: PlantDeviceScanLoader,
        connectionLoader: PlantDeviceConnectionLoader,
        pairingLoader: PlantDevicePairingLoader,
        actionHandler: @escaping (PlantDeviceAction) -> Void
    ) -> PlantDevicePickerView {
        let store = PlantDevicePickerStore()
        let viewModel = PlantDevicePickerViewModel(
            scanLoader: scanLoader,
            connectionLoader: connectionLoader,
            pairingLoader: pairingLoader,
            actionHandler: actionHandler
        )

        viewModel.loadedCandidates = { [weak store] candidates in
            store?.candidates = candidates
        }

        viewModel.loadedEmptyText = { [weak store] text in
            store?.emptyText = text
        }

        return PlantDevicePickerView(store: store, viewModel: viewModel)
    }
}
