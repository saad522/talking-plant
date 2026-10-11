import PlantMonitor
import SwiftUI

public struct PlantSensorChipView: View {
    @Environment(\.plantMonitorPalette) private var palette

    public let kind: PlantSensorKind
    public let isWarning: Bool
    private let viewModel: PlantSensorCardViewModel

    init(kind: PlantSensorKind, viewModel: PlantSensorCardViewModel, isWarning: Bool) {
        self.kind = kind
        self.viewModel = viewModel
        self.isWarning = isWarning
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(isWarning ? palette.warningValue : iconColor)
                Text(viewModel.value)
                    .font(PlantMonitorFont.chipValue)
                    .foregroundStyle(isWarning ? palette.warningValue : palette.ink)
            }
            Text(viewModel.title)
                .font(PlantMonitorFont.chipLabel)
                .foregroundStyle(isWarning ? palette.warningLabel : palette.inkSecondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.vertical, PlantMonitorSize.chipVerticalPadding)
        .padding(.horizontal, PlantMonitorSize.chipHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isWarning ? palette.warningFill : palette.card, in: shape)
        .overlay {
            if isWarning {
                shape.strokeBorder(palette.warningBorder, lineWidth: PlantMonitorSize.chipBorder)
            }
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PlantMonitorSize.chipRadius)
    }

    private var icon: String {
        switch kind {
        case .moisture: "drop.fill"
        case .light: "sun.max.fill"
        case .temperature: "thermometer.medium"
        case .humidity: "humidity.fill"
        }
    }

    private var iconColor: Color {
        switch kind {
        case .moisture, .humidity: palette.water
        case .light, .temperature: palette.streak
        }
    }
}
