import SwiftUI

/// Chip-shaped placeholders for the chip row.
public struct LoadingSkeletonView: View {
    @Environment(\.plantMonitorPalette) private var palette

    init() {}

    public var body: some View {
        HStack(spacing: PlantMonitorSize.chipSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: PlantMonitorSize.chipRadius)
                    .fill(palette.card)
                    .frame(height: PlantMonitorSize.chipHeight)
            }
        }
    }
}
