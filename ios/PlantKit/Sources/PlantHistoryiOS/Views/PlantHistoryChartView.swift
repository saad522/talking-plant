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

            yScaled(chart)
                .frame(height: 140)
        }
        .padding(16)
        .background(PlantHistoryColor.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private var chart: some View {
        Chart(viewModel.points) { point in
            LineMark(
                x: .value("Time", point.date),
                y: .value(viewModel.title, point.value)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(PlantHistoryColor.line)
        }
        .chartXScale(domain: viewModel.xDomain ?? Date.now.addingTimeInterval(-3_600)...Date.now, range: .plotDimension(endPadding: 16))
        .chartXAxis {
            AxisMarks(values: .stride(by: viewModel.xAxisStride.component, count: viewModel.xAxisStride.count)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(viewModel.xAxisLabel(for: date))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(viewModel.yAxisLabel(for: number))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func yScaled(_ chart: some View) -> some View {
        switch viewModel.yDomain {
        case .fixed(let domain):
            chart.chartYScale(domain: domain)
        case .automatic(let includesZero):
            chart.chartYScale(domain: .automatic(includesZero: includesZero))
        }
    }
}
