import PlantDevice
import SwiftUI

public struct PlantDeviceView: View {
    @ObservedObject private var store: PlantDeviceStore
    private let viewModel: PlantDeviceViewModel

    init(store: PlantDeviceStore, viewModel: PlantDeviceViewModel) {
        self.store = store
        self.viewModel = viewModel
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
            }
        }
        .navigationTitle(viewModel.title)
        .onAppear(perform: viewModel.appear)
    }

    private var mode: Binding<PlantDeviceMode> {
        Binding(get: { store.mode }, set: { viewModel.modeSelect($0) })
    }

    private var sensorSection: some View {
        Section(viewModel.sensorSectionLabel) {
            if let connection = store.connection {
                row(viewModel.statusLabel, connection.label)
                if connection.showsOpenSettings {
                    Button(viewModel.openSettingsLabel, action: viewModel.openSettingsTap)
                }
            }
            row(viewModel.pairedLabel, store.pairedName ?? viewModel.noSensorPairedLabel)
            if store.connection?.isConnected == true, let info = store.info {
                row(viewModel.firmwareLabel, info.firmware)
                row(viewModel.intervalLabel, info.interval)
            }
            if store.connection?.isConnected == true {
                Button(viewModel.readNowLabel, action: viewModel.readNowTap)
            }
            if let commandError = store.commandError {
                Text(commandError)
                    .font(PlantDeviceFont.notice)
                    .foregroundStyle(PlantDeviceColor.error)
            }
            Button(store.pairedName == nil ? viewModel.pairLabel : viewModel.changeLabel, action: viewModel.pairTap)
            if store.pairedName != nil {
                Button(viewModel.forgetLabel, role: .destructive, action: viewModel.forgetTap)
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
