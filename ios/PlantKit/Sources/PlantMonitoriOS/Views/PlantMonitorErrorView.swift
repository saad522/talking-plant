import PlantMonitor
import SwiftUI

public struct PlantMonitorErrorView: View {
    @ObservedObject private var store: PlantMonitorErrorStore
    private let viewModel: PlantMonitorErrorViewModel

    init(store: PlantMonitorErrorStore, viewModel: PlantMonitorErrorViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(PlantMonitorColor.background)
                .ignoresSafeArea()
            VStack(alignment: .center, spacing: 24) {
                store.icon
                    .font(PlantMonitorFont.icon)
                    .foregroundStyle(PlantMonitorColor.secondaryText)
                Text(viewModel.description)
                    .font(PlantMonitorFont.body)
                    .foregroundStyle(PlantMonitorColor.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button(action: viewModel.tap) {
                    Text(viewModel.buttonTitle)
                        .font(PlantMonitorFont.button)
                }
            }
        }
        .onAppear(perform: viewModel.appear)
    }
}
