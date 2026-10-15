import PlantDevice
import SwiftUI

public struct PlantDeviceCalibrationView: View {
    @ObservedObject private var store: PlantDeviceCalibrationStore
    private let viewModel: PlantDeviceCalibrationViewModel
    private let controls: PlantDeviceCalibrationControls

    init(store: PlantDeviceCalibrationStore, viewModel: PlantDeviceCalibrationViewModel, controls: PlantDeviceCalibrationControls) {
        self.store = store
        self.viewModel = viewModel
        self.controls = controls
    }

    public var body: some View {
        Form {
            Section(viewModel.title) {
                if let status = store.status {
                    row(viewModel.statusLabel, status.status)
                    row(viewModel.dryLabel, status.dry)
                    row(viewModel.wetLabel, status.wet)
                }
            }
            Section(viewModel.nowSectionLabel) {
                row(viewModel.soilLabel, store.liveSoil)
            }
            Section {
                captureRow(.dry, label: viewModel.captureDryLabel, draft: store.dryDraft)
            } header: {
                Text(viewModel.drySectionLabel)
            } footer: {
                Text(viewModel.dryHint)
            }
            Section {
                captureRow(.wet, label: viewModel.captureWetLabel, draft: store.wetDraft)
            } header: {
                Text(viewModel.wetSectionLabel)
            } footer: {
                Text(viewModel.wetHint)
            }
            Section {
                if let warning = store.warning {
                    notice(warning, color: PlantDeviceColor.warning)
                }
                if let message = store.message {
                    notice(message, color: PlantDeviceColor.error)
                }
                Button(viewModel.saveLabel, action: controls.save)
                    .disabled(store.canSave == false)
                if store.status?.isCalibrated == true {
                    Button(viewModel.resetLabel, role: .destructive, action: controls.reset)
                }
            } footer: {
                if store.canCapture == false {
                    Text(viewModel.offlineHint)
                }
            }
        }
        .navigationTitle(viewModel.title)
        .onAppear(perform: viewModel.appear)
    }

    private func captureRow(_ point: PlantDeviceCalibrationPoint, label: String, draft: String?) -> some View {
        HStack {
            Button(label) { controls.capture(point) }
                .disabled(store.canCapture == false || store.capturing != nil)
            Spacer()
            if store.capturing == point {
                ProgressView()
            } else if let draft {
                Text(draft)
                    .font(PlantDeviceFont.value)
                    .foregroundStyle(PlantDeviceColor.secondaryText)
            }
        }
    }

    private func notice(_ text: String, color: Color) -> some View {
        Text(text)
            .font(PlantDeviceFont.notice)
            .foregroundStyle(color)
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
