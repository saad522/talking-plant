import SwiftUI

enum PlantMonitorFont {
    // Error overlay.
    static let body: Font = .system(size: 16, weight: .regular)
    static let button: Font = .system(size: 16, weight: .semibold)
    static let icon: Font = .system(size: 40, weight: .regular)

    // Home screen (DESIGN.md section 3). Fixed sizes, not Dynamic Type.
    static let title: Font = .system(size: 30, weight: .heavy, design: .rounded)
    static let subtitle: Font = .system(size: 15, weight: .bold, design: .rounded)
    static let bubble: Font = .system(size: 15, weight: .bold, design: .rounded)
    static let chipValue: Font = .system(size: 17, weight: .heavy, design: .rounded)
    static let chipLabel: Font = .system(size: 12, weight: .bold, design: .rounded)
    static let primaryButton: Font = .system(size: 18, weight: .heavy, design: .rounded)
    static let secondaryButton: Font = .system(size: 16, weight: .heavy, design: .rounded)
    static let tabLabel: Font = .system(size: 12, weight: .bold, design: .rounded)

    /// Extra space between bubble lines for a line height of about 1.35.
    static let bubbleLineSpacing: CGFloat = 5
}
