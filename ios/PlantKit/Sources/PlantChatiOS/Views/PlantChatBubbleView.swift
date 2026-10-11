import SwiftUI

public struct PlantChatBubbleView: View, Identifiable {
    public enum Sender: Equatable {
        case plant
        case user
    }

    @Environment(\.plantChatColor) private var color

    public let id: Int
    public let text: String
    public let sender: Sender

    init(id: Int, text: String, sender: Sender) {
        self.id = id
        self.text = text
        self.sender = sender
    }

    public var body: some View {
        HStack(spacing: 0) {
            if sender == .user { Spacer(minLength: 0) }
            Text(text)
                .font(PlantChatFont.bubble)
                .lineSpacing(PlantChatFont.bubbleLineSpacing)
                .foregroundStyle(sender == .user ? color.userBubbleText : color.ink)
                .multilineTextAlignment(.leading)
                .padding(.vertical, PlantChatSize.bubbleVerticalPadding)
                .padding(.horizontal, PlantChatSize.bubbleHorizontalPadding)
                .background(sender == .user ? color.userBubble : color.card, in: shape)
                .frame(maxWidth: maxWidth, alignment: sender == .user ? .trailing : .leading)
            if sender == .plant { Spacer(minLength: 0) }
        }
    }

    private var maxWidth: CGFloat {
        sender == .user ? PlantChatSize.userBubbleMaxWidth : PlantChatSize.plantBubbleMaxWidth
    }

    /// The small corner points at the sender: bottom-left for the plant, bottom-right for you.
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: PlantChatSize.bubbleRadius,
            bottomLeadingRadius: sender == .plant ? PlantChatSize.bubbleTailRadius : PlantChatSize.bubbleRadius,
            bottomTrailingRadius: sender == .user ? PlantChatSize.bubbleTailRadius : PlantChatSize.bubbleRadius,
            topTrailingRadius: PlantChatSize.bubbleRadius
        )
    }
}
