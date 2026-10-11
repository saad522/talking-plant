import SwiftUI

/// Adaptive SwiftUI styles only, no asset catalog (see ARCHITECTURE.md section 5.5).
enum PlantHistoryColor {
    static let primaryText: Color = .primary
    static let secondaryText: Color = .secondary
    static let background: BackgroundStyle = .background
    static let cardBackground: Color = .secondary.opacity(0.12)
    static let line: Color = .accentColor
}
