import SwiftUI

/// SF Pro Rounded, fixed sizes (DESIGN.md section 3).
enum PlantChatFont {
    static let title: Font = .system(size: 22, weight: .heavy, design: .rounded)
    static let subtitle: Font = .system(size: 14, weight: .bold, design: .rounded)
    static let bubble: Font = .system(size: 16, weight: .bold, design: .rounded)
    static let notice: Font = .system(size: 13, weight: .bold, design: .rounded)
    static let input: Font = .system(size: 16, weight: .semibold, design: .rounded)
    static let headerIcon: Font = .system(size: 18, weight: .bold, design: .rounded)
    static let sendIcon: Font = .system(size: 18, weight: .heavy, design: .rounded)
    static let micIcon: Font = .system(size: 30, weight: .heavy, design: .rounded)

    /// Extra space between bubble lines for a line height of about 1.35.
    static let bubbleLineSpacing: CGFloat = 5
}
