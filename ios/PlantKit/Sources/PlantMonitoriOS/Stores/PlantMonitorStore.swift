import SwiftUI

@MainActor
final class PlantMonitorStore<Face: View>: ObservableObject {
    @Published var palette: PlantMonitorPalette = .day
    @Published var title: String = ""
    @Published var subtitle: String = ""
    @Published var window: PlantMonitorWindowView = PlantMonitorWindowView(celestial: .sun)
    @Published var face: Face?
    @Published var bubble: PlantSpeechBubbleView?
    @Published var chips: [PlantSensorChipView] = []
    @Published var primaryButton: PlantMonitorButtonView?
    @Published var secondaryButtons: [PlantMonitorButtonView] = []
    @Published var loading: LoadingSkeletonView? = LoadingSkeletonView()
    @Published var error: PlantMonitorErrorView?
}
