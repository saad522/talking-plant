import PlantMonitor
import SwiftUI

public struct PlantMoodView<Face: View>: View {
    private let viewModel: PlantMoodViewModel
    private let face: Face

    init(viewModel: PlantMoodViewModel, face: Face) {
        self.viewModel = viewModel
        self.face = face
    }

    public var body: some View {
        VStack(spacing: 8) {
            face
            Text(viewModel.label)
                .font(PlantMonitorFont.moodLabel)
                .foregroundStyle(PlantMonitorColor.primaryText)
        }
        .frame(maxWidth: .infinity)
    }
}
