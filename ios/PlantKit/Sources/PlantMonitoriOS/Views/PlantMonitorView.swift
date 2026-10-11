import PlantMonitor
import SwiftUI

public struct PlantMonitorView: View {
    @ObservedObject private var store: PlantMonitorStore
    private let viewModel: PlantMonitorViewModel

    init(store: PlantMonitorStore, viewModel: PlantMonitorViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    store.moisture
                    store.light
                    store.temperature
                    store.humidity
                }

                Button(action: viewModel.historyTap) {
                    Text(viewModel.historyLabel)
                        .font(PlantMonitorFont.button)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
        .overlay { store.loading }
        .overlay { store.error }
        .onAppear(perform: viewModel.appear)
    }
}
