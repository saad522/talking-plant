import SwiftUI

public struct PlantChatNoticeView: View {
    @Environment(\.plantChatColor) private var color

    public let text: String

    init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(PlantChatFont.notice)
            .foregroundStyle(color.inkSecondary)
            .multilineTextAlignment(.center)
            .padding(PlantChatSize.noticePadding)
            .frame(maxWidth: .infinity)
            .background(color.card, in: RoundedRectangle(cornerRadius: PlantChatSize.noticeRadius))
            .padding(.horizontal, PlantChatSize.screenPadding)
    }
}
