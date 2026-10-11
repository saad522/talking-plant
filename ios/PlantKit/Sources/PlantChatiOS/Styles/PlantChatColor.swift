import SwiftUI

/// Fixed design colors (DESIGN.md section 2). The Talk screen follows the system appearance:
/// day tokens in light mode, night tokens in dark mode.
struct PlantChatColor: Equatable, Sendable {
    let background: Color
    let card: Color
    let ink: Color
    let inkSecondary: Color
    let primary: Color
    /// Icon on the filled `primary` send button.
    let onPrimary: Color
    /// Background and text of your own bubbles: the screen's `ink`, inverted.
    let userBubble: Color
    let userBubbleText: Color

    static let day = PlantChatColor(
        background: Color(hex: 0xEEF4E6),
        card: Color(hex: 0xFFFFFF),
        ink: Color(hex: 0x1F2A24),
        inkSecondary: Color(hex: 0x4D5B53),
        primary: Color(hex: 0x237A40),
        onPrimary: Color(hex: 0xFFFFFF),
        userBubble: Color(hex: 0x1F2A24),
        userBubbleText: Color(hex: 0xFFFFFF)
    )

    static let night = PlantChatColor(
        background: Color(hex: 0x17202B),
        card: Color(hex: 0x263241),
        ink: Color(hex: 0xEEF2F6),
        inkSecondary: Color(hex: 0xA9B6C6),
        primary: Color(hex: 0x7BD39A),
        onPrimary: Color(hex: 0x0F2418),
        userBubble: Color(hex: 0xEEF2F6),
        userBubbleText: Color(hex: 0x1F2A24)
    )

    init(
        background: Color,
        card: Color,
        ink: Color,
        inkSecondary: Color,
        primary: Color,
        onPrimary: Color,
        userBubble: Color,
        userBubbleText: Color
    ) {
        self.background = background
        self.card = card
        self.ink = ink
        self.inkSecondary = inkSecondary
        self.primary = primary
        self.onPrimary = onPrimary
        self.userBubble = userBubble
        self.userBubbleText = userBubbleText
    }

    init(_ scheme: ColorScheme) {
        self = scheme == .dark ? .night : .day
    }
}

extension EnvironmentValues {
    @Entry var plantChatColor: PlantChatColor = .day
}
