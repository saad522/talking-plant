import PlantDevice
import PlantShared
import SwiftUI

public struct PlantDeviceView: View {
    @ObservedObject private var store: PlantDeviceStore
    private let viewModel: PlantDeviceViewModel
    private let showsRawReading: Bool
    private let controls: PlantDeviceControls
    private let placeholder = PlantReadingFormatter.placeholder
    @State private var confirmsClearHistory = false

    init(store: PlantDeviceStore, viewModel: PlantDeviceViewModel, showsRawReading: Bool, controls: PlantDeviceControls) {
        self.store = store
        self.viewModel = viewModel
        self.showsRawReading = showsRawReading
        self.controls = controls
    }

    public var body: some View {
        Form {
            Section(viewModel.modeSectionLabel) {
                Picker(viewModel.modeSectionLabel, selection: mode) {
                    ForEach(viewModel.modes, id: \.mode) { option in
                        Text(option.label).tag(option.mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            if store.mode == .sensor {
                sensorSection
                if showsRawReading {
                    rawReadingSection
                }
            }
        }
        .navigationTitle(viewModel.title)
        .onAppear(perform: viewModel.appear)
    }

    private var mode: Binding<PlantDeviceMode> {
        Binding(get: { store.mode }, set: controls.modeSelect)
    }

    private var sensorSection: some View {
        Section(viewModel.sensorSectionLabel) {
            if let connection = store.connection {
                row(viewModel.statusLabel, connection.label)
                if connection.showsOpenSettings {
                    Button(viewModel.openSettingsLabel, action: controls.openSettings)
                }
            }
            row(viewModel.pairedLabel, store.pairedName ?? viewModel.noSensorPairedLabel)
            if store.connection?.isConnected == true, let info = store.info {
                row(viewModel.firmwareLabel, info.firmware)
                row(viewModel.intervalLabel, info.interval)
            }
            if store.connection?.isConnected == true {
                Button(viewModel.readNowLabel, action: controls.readNow)
            }
            if let commandError = store.commandError {
                Text(commandError)
                    .font(PlantDeviceFont.notice)
                    .foregroundStyle(PlantDeviceColor.error)
            }
            Button(action: controls.calibration) {
                row(viewModel.calibrationLabel, store.calibrationStatus)
            }
            Button(store.pairedName == nil ? viewModel.pairLabel : viewModel.changeLabel, action: controls.pair)
            if store.pairedName != nil {
                Button(viewModel.forgetLabel, role: .destructive, action: controls.forget)
            }
        }
    }

    private var rawReadingSection: some View {
        Section(viewModel.rawSectionLabel) {
            row(viewModel.rawSoilLabel, store.rawReading?.soil ?? placeholder)
            row(viewModel.rawLightLabel, store.rawReading?.light ?? placeholder)
            row(viewModel.rawTemperatureLabel, store.rawReading?.temperature ?? placeholder)
            row(viewModel.rawHumidityLabel, store.rawReading?.humidity ?? placeholder)
            row(viewModel.rawFlagsLabel, store.rawReading?.flags ?? placeholder)
            row(viewModel.rawSequenceLabel, store.rawReading?.sequence ?? placeholder)
            row(viewModel.rawReceivedLabel, store.rawReading?.received ?? placeholder)
            Button(viewModel.clearHistoryLabel, role: .destructive) {
                controls.clearHistory()
                confirmsClearHistory = true
            }
                .alert(viewModel.clearHistoryTitle, isPresented: $confirmsClearHistory) {
                    Button(viewModel.clearHistoryConfirmLabel, role: .destructive, action: controls.clearHistoryConfirm)
                    Button(viewModel.clearHistoryCancelLabel, role: .cancel, action: controls.clearHistoryCancel)
                } message: {
                    Text(viewModel.clearHistoryMessage)
                }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(PlantDeviceFont.body)
                .foregroundStyle(PlantDeviceColor.primaryText)
            Spacer()
            Text(value)
                .font(PlantDeviceFont.value)
                .foregroundStyle(PlantDeviceColor.secondaryText)
        }
    }
}
