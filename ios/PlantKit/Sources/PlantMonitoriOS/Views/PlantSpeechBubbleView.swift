import SwiftUI

public struct PlantSpeechBubbleView: View {
    @Environment(\.plantMonitorPalette) private var palette

    public let text: String

    init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(PlantMonitorFont.bubble)
            .lineSpacing(PlantMonitorFont.bubbleLineSpacing)
            .foregroundStyle(palette.ink)
            .multilineTextAlignment(.leading)
            .padding(.vertical, PlantMonitorSize.bubbleVerticalPadding)
            .padding(.horizontal, PlantMonitorSize.bubbleHorizontalPadding)
            .frame(width: PlantMonitorSize.bubbleWidth, alignment: .leading)
            .background(
                palette.card,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: PlantMonitorSize.bubbleRadius,
                    bottomLeadingRadius: PlantMonitorSize.bubbleTailRadius,
                    bottomTrailingRadius: PlantMonitorSize.bubbleRadius,
                    topTrailingRadius: PlantMonitorSize.bubbleRadius
                )
            )
    }
}
