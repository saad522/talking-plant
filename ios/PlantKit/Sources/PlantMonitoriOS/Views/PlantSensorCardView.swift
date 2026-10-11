import PlantMonitor
import SwiftUI

public struct PlantSensorCardView: View {
    private let viewModel: PlantSensorCardViewModel

    init(viewModel: PlantSensorCardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.title)
                .font(PlantMonitorFont.caption)
                .foregroundStyle(PlantMonitorColor.secondaryText)
            Text(viewModel.value)
                .font(PlantMonitorFont.value)
                .foregroundStyle(PlantMonitorColor.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PlantMonitorColor.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}
