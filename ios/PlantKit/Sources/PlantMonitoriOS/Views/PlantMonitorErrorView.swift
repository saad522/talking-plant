import PlantMonitor
import SwiftUI

public struct PlantMonitorErrorView: View {
    @ObservedObject private var store: PlantMonitorErrorStore
    private let viewModel: PlantMonitorErrorViewModel
    private let tap: () -> Void

    init(store: PlantMonitorErrorStore, viewModel: PlantMonitorErrorViewModel, tap: @escaping () -> Void) {
        self.store = store
        self.viewModel = viewModel
        self.tap = tap
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
                Button(action: tap) {
                    Text(viewModel.buttonTitle)
                        .font(PlantMonitorFont.button)
                }
            }
        }
        .onAppear(perform: viewModel.appear)
    }
}
