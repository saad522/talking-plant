import PlantDevice
import SwiftUI

public struct PlantDevicePickerView: View {
    @ObservedObject private var store: PlantDevicePickerStore
    private let viewModel: PlantDevicePickerViewModel
    private let select: (PlantDeviceCandidateViewModel) -> Void

    init(store: PlantDevicePickerStore, viewModel: PlantDevicePickerViewModel, select: @escaping (PlantDeviceCandidateViewModel) -> Void) {
        self.store = store
        self.viewModel = viewModel
        self.select = select
    }

    public var body: some View {
        List {
            if store.candidates.isEmpty {
                Text(store.emptyText)
                    .font(PlantDeviceFont.notice)
                    .foregroundStyle(PlantDeviceColor.secondaryText)
            }
            ForEach(store.candidates, id: \.candidate.identifier) { candidate in
                Button {
                    select(candidate)
                } label: {
                    HStack {
                        Text(candidate.name)
                            .font(PlantDeviceFont.body)
                            .foregroundStyle(PlantDeviceColor.primaryText)
                        Spacer()
                        Image(systemName: "cellularbars", variableValue: Double(candidate.signalBars) / 3)
                            .foregroundStyle(PlantDeviceColor.secondaryText)
                    }
                }
            }
        }
        .navigationTitle(viewModel.title)
        .onAppear(perform: viewModel.appear)
        .onDisappear(perform: viewModel.disappear)
    }
}
