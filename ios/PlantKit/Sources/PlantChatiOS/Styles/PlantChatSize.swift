import SwiftUI

/// Sizes of the Talk screen (DESIGN.md section 6, 390 pt wide reference).
enum PlantChatSize {
    static let screenPadding: CGFloat = 20
    static let headerButton: CGFloat = 44
    static let headerSpacing: CGFloat = 12

    /// The Sprout is drawn 270 × 315 pt; this is the 240 × 280 ratio at 200 pt wide.
    static let faceSize = CGSize(width: 200, height: 233)
    static let faceDrawnWidth: CGFloat = 270

    static let bubbleSpacing: CGFloat = 10
    static let plantBubbleMaxWidth: CGFloat = 290
    static let userBubbleMaxWidth: CGFloat = 250
    static let bubbleRadius: CGFloat = 20
    static let bubbleTailRadius: CGFloat = 6
    static let bubbleVerticalPadding: CGFloat = 12
    static let bubbleHorizontalPadding: CGFloat = 14

    static let noticeRadius: CGFloat = 14
    static let noticePadding: CGFloat = 10

    static let inputHeight: CGFloat = 48
    static let sendButton: CGFloat = 48
    static let inputSpacing: CGFloat = 10
    static let inputHorizontalPadding: CGFloat = 16
}
