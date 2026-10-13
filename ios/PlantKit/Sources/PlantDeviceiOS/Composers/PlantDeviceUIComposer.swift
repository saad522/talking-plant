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

        return PlantDeviceView(store: store, viewModel: viewModel)
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
