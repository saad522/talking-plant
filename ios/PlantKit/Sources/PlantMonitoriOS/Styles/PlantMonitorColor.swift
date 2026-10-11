import SwiftUI

/// Adaptive styles for the error overlay. The home screen uses `PlantMonitorPalette` instead.
enum PlantMonitorColor {
    static let primaryText: Color = .primary
    static let secondaryText: Color = .secondary
    static let background: BackgroundStyle = .background
    static let cardBackground: Color = .secondary.opacity(0.12)
}

/// Fixed design colors (DESIGN.md section 2), chosen by the scene, not by the system appearance.
struct PlantMonitorPalette: Equatable, Sendable {
    let background: Color
    let scene: Color
    let sky: Color
    let windowFrame: Color
    let sun: Color
    let moon: Color
    let sill: Color
    let floor: Color
    let card: Color
    let ink: Color
    let inkSecondary: Color
    let inkTertiary: Color
    let primary: Color
    /// Text and icons on a filled `primary` or `water` button.
    let onPrimary: Color
    let water: Color
    let streak: Color
    let warningFill: Color
    let warningBorder: Color
    let warningValue: Color
    let warningLabel: Color
    /// Set on the home screen's toolbar so the status bar stays readable on this palette.
    let colorScheme: ColorScheme

    static let day = PlantMonitorPalette(
        background: Color(hex: 0xEEF4E6),
        scene: Color(hex: 0xDCEBD3),
        sky: Color(hex: 0xCFE6F5),
        windowFrame: Color(hex: 0xFFFFFF),
        sun: Color(hex: 0xFFD66B),
        moon: Color(hex: 0xF3E7B3),
        sill: Color(hex: 0xD8B892),
        floor: Color(hex: 0xCFE2C4),
        card: Color(hex: 0xFFFFFF),
        ink: Color(hex: 0x1F2A24),
        inkSecondary: Color(hex: 0x4D5B53),
        inkTertiary: Color(hex: 0x56645C),
        primary: Color(hex: 0x237A40),
        onPrimary: Color(hex: 0xFFFFFF),
        water: Color(hex: 0x236DAD),
        streak: Color(hex: 0xB4531F),
        warningFill: Color(hex: 0xFFF1DE),
        warningBorder: Color(hex: 0xE9A55A),
        warningValue: Color(hex: 0x9A3F12),
        warningLabel: Color(hex: 0x7A4A2A),
        colorScheme: .light
    )

    static let thirsty = PlantMonitorPalette(
        background: Color(hex: 0xF4EEE2),
        scene: Color(hex: 0xEADFCB),
        sky: Color(hex: 0xDDE9F0),
        windowFrame: day.windowFrame,
        sun: day.sun,
        moon: day.moon,
        sill: day.sill,
        floor: Color(hex: 0xE2D4BC),
        card: day.card,
        ink: day.ink,
        inkSecondary: day.inkSecondary,
        inkTertiary: day.inkTertiary,
        primary: day.primary,
        onPrimary: day.onPrimary,
        water: day.water,
        streak: day.streak,
        warningFill: day.warningFill,
        warningBorder: day.warningBorder,
        warningValue: day.warningValue,
        warningLabel: day.warningLabel,
        colorScheme: .light
    )

    static let night = PlantMonitorPalette(
        background: Color(hex: 0x17202B),
        scene: Color(hex: 0x223042),
        sky: Color(hex: 0x2E4260),
        windowFrame: Color(hex: 0x3A4A60),
        sun: day.sun,
        moon: Color(hex: 0xF3E7B3),
        sill: Color(hex: 0x4A4236),
        floor: Color(hex: 0x1C2836),
        card: Color(hex: 0x263241),
        ink: Color(hex: 0xEEF2F6),
        inkSecondary: Color(hex: 0xA9B6C6),
        inkTertiary: Color(hex: 0xA9B6C6),
        primary: Color(hex: 0x7BD39A),
        onPrimary: Color(hex: 0x0F2418),
        water: Color(hex: 0x8EC3F0),
        streak: Color(hex: 0xF2B07A),
        warningFill: day.warningFill,
        warningBorder: day.warningBorder,
        warningValue: day.warningValue,
        warningLabel: day.warningLabel,
        colorScheme: .dark
    )
}

extension EnvironmentValues {
    @Entry var plantMonitorPalette: PlantMonitorPalette = .day
}
