import SwiftUI

public struct PlantMonitorHeaderView: View {
    @Environment(\.plantMonitorPalette) private var palette

    public let title: String
    public let subtitle: String

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(PlantMonitorFont.title)
                .foregroundStyle(palette.ink)
            Text(subtitle)
                .font(PlantMonitorFont.subtitle)
                .foregroundStyle(palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PlantMonitorSize.headerPadding)
    }
}
