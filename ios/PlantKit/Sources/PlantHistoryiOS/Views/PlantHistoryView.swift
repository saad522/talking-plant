import PlantHistory
import SwiftUI

public struct PlantHistoryView: View {
    @ObservedObject private var store: PlantHistoryStore
    private let viewModel: PlantHistoryViewModel

    init(store: PlantHistoryStore, viewModel: PlantHistoryViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Picker(viewModel.title, selection: Binding(get: { store.selectedRange }, set: { viewModel.select($0) })) {
                    ForEach(viewModel.ranges, id: \.self) { range in
                        Text(viewModel.title(for: range)).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                store.moisture
                store.light
                store.temperature
                store.humidity
            }
            .padding(16)
        }
        .overlay { store.loading }
        .overlay { store.message }
        .navigationTitle(viewModel.title)
        .onAppear(perform: viewModel.appear)
    }
}
