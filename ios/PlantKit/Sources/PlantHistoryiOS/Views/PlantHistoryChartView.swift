import Charts
import PlantHistory
import SwiftUI

public struct PlantHistoryChartView: View {
    private let viewModel: PlantHistoryChartViewModel

    init(viewModel: PlantHistoryChartViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.title)
                    .font(PlantHistoryFont.caption)
                    .foregroundStyle(PlantHistoryColor.secondaryText)
                Spacer()
                Text(viewModel.latestValue)
                    .font(PlantHistoryFont.value)
                    .foregroundStyle(PlantHistoryColor.primaryText)
            }

            Chart(viewModel.points) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value(viewModel.title, point.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(PlantHistoryColor.line)
            }
            .frame(height: 140)
        }
        .padding(16)
        .background(PlantHistoryColor.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}
