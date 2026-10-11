import PlantMonitor
import SwiftUI

public struct PlantMonitorView<Face: View>: View {
    @ObservedObject private var store: PlantMonitorStore<Face>
    private let viewModel: PlantMonitorViewModel

    init(store: PlantMonitorStore<Face>, viewModel: PlantMonitorViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PlantMonitorSize.screenSpacing) {
                PlantMonitorHeaderView(title: store.title, subtitle: store.subtitle)
                PlantMonitorSceneView(store: store)
                actions
            }
            .padding(.bottom, PlantMonitorSize.screenSpacing)
        }
        .background { store.palette.background.ignoresSafeArea() }
        .environment(\.plantMonitorPalette, store.palette)
        .preferredColorScheme(store.palette.colorScheme)
        .overlay { store.error }
        .onAppear(perform: viewModel.appear)
    }

    private var actions: some View {
        VStack(spacing: PlantMonitorSize.actionsSpacing) {
            if let primary = store.primaryButton {
                primary
            }
            HStack(spacing: PlantMonitorSize.actionsSpacing) {
                ForEach(store.secondaryButtons.indices, id: \.self) { index in
                    store.secondaryButtons[index]
                }
            }
        }
        .padding(.horizontal, PlantMonitorSize.actionsPadding)
    }
}
