import SwiftUI

public struct PlantMonitorButtonView: View {
    public enum Style: Equatable {
        case primary
        case secondary
    }

    @Environment(\.plantMonitorPalette) private var palette

    public let title: String
    public let style: Style
    private let systemImage: String
    private let accent: KeyPath<PlantMonitorPalette, Color>
    private let action: () -> Void

    init(
        title: String,
        systemImage: String,
        style: Style,
        accent: KeyPath<PlantMonitorPalette, Color>,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: PlantMonitorSize.buttonIconSpacing) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(style == .primary ? PlantMonitorFont.primaryButton : PlantMonitorFont.secondaryButton)
            .foregroundStyle(style == .primary ? palette.onPrimary : palette[keyPath: accent])
            .frame(maxWidth: .infinity)
            .frame(height: style == .primary ? PlantMonitorSize.primaryButtonHeight : PlantMonitorSize.secondaryButtonHeight)
            .background(style == .primary ? palette[keyPath: accent] : palette.card, in: Capsule())
            .overlay {
                if style == .secondary {
                    Capsule().strokeBorder(palette[keyPath: accent], lineWidth: PlantMonitorSize.secondaryButtonBorder)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
