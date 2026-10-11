import SwiftUI

public struct PlantMonitorWindowView: View {
    public enum Celestial: Equatable {
        case sun
        case moon
    }

    @Environment(\.plantMonitorPalette) private var palette

    public let celestial: Celestial

    init(celestial: Celestial) {
        self.celestial = celestial
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
                case .sun: sun(in: glass)
                case .moon: moon(in: glass)
                }
                palette.windowFrame
                    .frame(width: PlantMonitorSize.windowPane)
                    .frame(maxWidth: .infinity)
                palette.windowFrame
                    .frame(height: PlantMonitorSize.windowPane)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: glass.width, height: glass.height)
            .clipShape(RoundedRectangle(cornerRadius: PlantMonitorSize.windowRadius - border))
            .offset(x: border, y: border)
        }
        .frame(width: PlantMonitorSize.windowSize.width, height: PlantMonitorSize.windowSize.height)
    }

    private func sun(in glass: CGSize) -> some View {
        Circle()
            .fill(palette.sun)
            .frame(width: PlantMonitorSize.sunDiameter, height: PlantMonitorSize.sunDiameter)
            .offset(
                x: glass.width - PlantMonitorSize.sunDiameter - PlantMonitorSize.celestialInset,
                y: PlantMonitorSize.celestialInset
            )
    }

    /// A crescent: the moon circle with a sky circle offset over it, plus a few stars.
    private func moon(in glass: CGSize) -> some View {
        let x = glass.width - PlantMonitorSize.moonDiameter - PlantMonitorSize.celestialInset
        let y = PlantMonitorSize.celestialInset
        let cutInset = (PlantMonitorSize.moonDiameter - PlantMonitorSize.moonCutDiameter) / 2
        return ZStack(alignment: .topLeading) {
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
            ForEach(0..<PlantMonitorSize.starDiameters.count, id: \.self) { index in
                Circle()
                    .fill(palette.moon)
                    .frame(width: PlantMonitorSize.starDiameters[index], height: PlantMonitorSize.starDiameters[index])
                    .offset(x: PlantMonitorSize.starOffsets[index].x, y: PlantMonitorSize.starOffsets[index].y)
            }
        }
    }
}
