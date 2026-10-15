import SwiftUI

public struct PlantMonitorWindowView: View {
    public enum Celestial: Equatable {
        case sun
        case moon
    }

    @Environment(\.plantMonitorPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let celestial: Celestial
    /// Where the body sits on its arc, 0 (left, low) to 1 (right, low).
    public let progress: Double
    /// A small move from the last position: it slides. Anything else jumps.
    public let isGradual: Bool

    init(celestial: Celestial, progress: Double, isGradual: Bool) {
        self.celestial = celestial
        self.progress = progress
        self.isGradual = isGradual
    }

    public var body: some View {
        let border = PlantMonitorSize.windowBorder
        let glass = CGSize(
            width: PlantMonitorSize.windowSize.width - border * 2,
            height: PlantMonitorSize.windowSize.height - border * 2
        )
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: PlantMonitorSize.windowRadius).fill(palette.windowFrame)
            ZStack(alignment: .topLeading) {
                palette.sky
                switch celestial {
                case .sun: sun(in: glass).transition(.opacity)
                case .moon: moon(in: glass).transition(.opacity)
                }
                palette.windowFrame
                    .frame(width: PlantMonitorSize.windowPane)
                    .frame(maxWidth: .infinity)
                palette.windowFrame
                    .frame(height: PlantMonitorSize.windowPane)
                    .frame(maxHeight: .infinity)
            }
            .animation(
                reduceMotion ? nil : .easeInOut(duration: PlantMonitorSize.sceneFadeDuration),
                value: celestial
            )
            .frame(width: glass.width, height: glass.height)
            .clipShape(RoundedRectangle(cornerRadius: PlantMonitorSize.windowRadius - border))
            .offset(x: border, y: border)
        }
        .frame(width: PlantMonitorSize.windowSize.width, height: PlantMonitorSize.windowSize.height)
    }

    /// The centre of a body of `diameter` on its arc: x runs from inset to inset, y rises and falls with a sine.
    private func center(of diameter: CGFloat, in glass: CGSize) -> CGPoint {
        let minX = PlantMonitorSize.celestialInset + diameter / 2
        let maxX = glass.width - PlantMonitorSize.celestialInset - diameter / 2
        return CGPoint(
            x: minX + (maxX - minX) * progress,
            y: PlantMonitorSize.skyHorizon - sin(.pi * progress) * PlantMonitorSize.skyRise
        )
    }

    private var slide: Animation? {
        isGradual && !reduceMotion ? .linear(duration: PlantMonitorSize.skySlideDuration) : nil
    }

    private func sun(in glass: CGSize) -> some View {
        let center = center(of: PlantMonitorSize.sunDiameter, in: glass)
        return Circle()
            .fill(palette.sun)
            .frame(width: PlantMonitorSize.sunDiameter, height: PlantMonitorSize.sunDiameter)
            .offset(
                x: center.x - PlantMonitorSize.sunDiameter / 2,
                y: center.y - PlantMonitorSize.sunDiameter / 2
            )
            .animation(slide, value: progress)
    }

    /// A crescent: the moon circle with a sky circle offset over it, plus a few stars.
    private func moon(in glass: CGSize) -> some View {
        let center = center(of: PlantMonitorSize.moonDiameter, in: glass)
        let x = center.x - PlantMonitorSize.moonDiameter / 2
        let y = center.y - PlantMonitorSize.moonDiameter / 2
        let cutInset = (PlantMonitorSize.moonDiameter - PlantMonitorSize.moonCutDiameter) / 2
        return ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(palette.moon)
                    .frame(width: PlantMonitorSize.moonDiameter, height: PlantMonitorSize.moonDiameter)
                    .offset(x: x, y: y)
                Circle()
                    .fill(palette.sky)
                    .frame(width: PlantMonitorSize.moonCutDiameter, height: PlantMonitorSize.moonCutDiameter)
                    .offset(
                        x: x + cutInset + PlantMonitorSize.moonCutOffset.width,
                        y: y + cutInset + PlantMonitorSize.moonCutOffset.height
                    )
            }
            .animation(slide, value: progress)
            ForEach(0..<PlantMonitorSize.starDiameters.count, id: \.self) { index in
                Circle()
                    .fill(palette.moon)
                    .frame(width: PlantMonitorSize.starDiameters[index], height: PlantMonitorSize.starDiameters[index])
                    .offset(x: PlantMonitorSize.starOffsets[index].x, y: PlantMonitorSize.starOffsets[index].y)
            }
        }
    }
}
