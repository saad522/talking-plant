import SwiftUI

public struct LoadingSkeletonView: View {
    init() {}

    public var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(PlantMonitorColor.cardBackground)
                    .frame(height: 88)
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
