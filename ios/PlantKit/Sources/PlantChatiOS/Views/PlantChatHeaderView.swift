import SwiftUI

public struct PlantChatHeaderView: View {
    @Environment(\.plantChatColor) private var color

    public let title: String
    public let subtitle: String
    public let backLabel: String
    public let personalityMenu: PlantChatPersonalityMenuView?
    private let back: () -> Void

    init(
        title: String,
        subtitle: String,
        backLabel: String,
        personalityMenu: PlantChatPersonalityMenuView?,
        back: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.backLabel = backLabel
        self.personalityMenu = personalityMenu
        self.back = back
    }

    public var body: some View {
        HStack(spacing: PlantChatSize.headerSpacing) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(PlantChatFont.headerIcon)
                    .foregroundStyle(color.ink)
                    .frame(width: PlantChatSize.headerButton, height: PlantChatSize.headerButton)
                    .background(color.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(backLabel)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PlantChatFont.title)
                    .foregroundStyle(color.ink)
                Text(subtitle)
                    .font(PlantChatFont.subtitle)
                    .foregroundStyle(color.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            personalityMenu
        }
        .padding(.horizontal, PlantChatSize.screenPadding)
    }
}
