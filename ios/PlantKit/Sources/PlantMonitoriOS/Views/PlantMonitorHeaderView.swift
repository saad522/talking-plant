import SwiftUI

public struct PlantMonitorHeaderView: View {
    @Environment(\.plantMonitorPalette) private var palette

    public let title: String
    public let subtitle: String
    public let settingsLabel: String
    private let settingsAction: () -> Void

    init(title: String, subtitle: String, settingsLabel: String, settingsAction: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.settingsLabel = settingsLabel
        self.settingsAction = settingsAction
    }

    public var body: some View {
        HStack(spacing: PlantMonitorSize.headerSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PlantMonitorFont.title)
                    .foregroundStyle(palette.ink)
                Text(subtitle)
                    .font(PlantMonitorFont.subtitle)
                    .foregroundStyle(palette.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: settingsAction) {
                Image(systemName: "slider.horizontal.3")
                    .font(PlantMonitorFont.subtitle)
                    .foregroundStyle(palette.ink)
                    .frame(width: PlantMonitorSize.settingsButton, height: PlantMonitorSize.settingsButton)
                    .background(palette.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(settingsLabel)
        }
        .padding(.horizontal, PlantMonitorSize.headerPadding)
    }
}
