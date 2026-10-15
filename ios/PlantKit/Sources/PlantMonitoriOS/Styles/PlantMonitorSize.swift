import SwiftUI

/// Sizes of the home screen (DESIGN.md section 4, 390 pt wide reference).
enum PlantMonitorSize {
    static let screenSpacing: CGFloat = 16
    static let headerPadding: CGFloat = 20
    static let headerSpacing: CGFloat = 12
    /// DESIGN.md section 4: a 44 pt round settings button.
    static let settingsButton: CGFloat = 44
    static let actionsPadding: CGFloat = 20
    static let actionsSpacing: CGFloat = 10

    /// Scene changes (palette, sun to moon) cross-fade over this long, unless Reduce Motion is on.
    static let sceneFadeDuration: Double = 1

    static let sceneMargin: CGFloat = 16
    static let sceneHeight: CGFloat = 440
    static let sceneRadius: CGFloat = 32

    static let windowSize = CGSize(width: 170, height: 180)
    static let windowRadius: CGFloat = 26
    static let windowBorder: CGFloat = 10
    static let windowPane: CGFloat = 8
    static let windowTop: CGFloat = 24
    /// 390 pt reference: the window starts at x 150 in a 358 pt card.
    static let windowTrailing: CGFloat = 38
    static let sunDiameter: CGFloat = 44
    static let moonDiameter: CGFloat = 40
    static let moonCutDiameter: CGFloat = 36
    static let moonCutOffset = CGSize(width: 10, height: -6)
    static let celestialInset: CGFloat = 14
    /// The sun and moon centres sit on an arc: y of the centre at both ends of the arc (inside the glass).
    static let skyHorizon: CGFloat = 120
    /// How far above the horizon the centre climbs at the top of the arc.
    static let skyRise: CGFloat = 80
    /// A one-minute step slides over this long, so the body moves continuously.
    static let skySlideDuration: Double = 60
    static let starDiameters: [CGFloat] = [5, 4, 4, 5]
    static let starOffsets: [CGPoint] = [CGPoint(x: 28, y: 26), CGPoint(x: 50, y: 56), CGPoint(x: 24, y: 104), CGPoint(x: 112, y: 112)]

    static let sillHeight: CGFloat = 26
    static let sillBottom: CGFloat = 76
    static let floorHeight: CGFloat = sillBottom
    static let faceBottom: CGFloat = 84

    static let bubbleLeading: CGFloat = 14
    static let bubbleTop: CGFloat = 18
    static let bubbleWidth: CGFloat = 168
    static let bubbleRadius: CGFloat = 20
    static let bubbleTailRadius: CGFloat = 6
    static let bubbleVerticalPadding: CGFloat = 12
    static let bubbleHorizontalPadding: CGFloat = 14
    /// Three lines of the bubble font (15 pt text, about 18 pt tall, plus 5 pt spacing) and the padding.
    static let bubbleHeight: CGFloat = 3 * 18 + 2 * PlantMonitorFont.bubbleLineSpacing + 2 * bubbleVerticalPadding

    static let chipSpacing: CGFloat = 8
    static let chipInset: CGFloat = 12
    static let chipRadius: CGFloat = 16
    static let chipVerticalPadding: CGFloat = 10
    static let chipHorizontalPadding: CGFloat = 12
    static let chipBorder: CGFloat = 2
    static let chipHeight: CGFloat = 60

    static let primaryButtonHeight: CGFloat = 56
    static let secondaryButtonHeight: CGFloat = 48
    static let secondaryButtonBorder: CGFloat = 2
    static let buttonIconSpacing: CGFloat = 8
}
