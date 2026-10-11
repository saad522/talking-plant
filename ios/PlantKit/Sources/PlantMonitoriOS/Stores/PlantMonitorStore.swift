import SwiftUI

@MainActor
final class PlantMonitorStore<Face: View>: ObservableObject {
    @Published var mood: PlantMoodView<Face>?
    @Published var moisture: PlantSensorCardView?
    @Published var light: PlantSensorCardView?
    @Published var temperature: PlantSensorCardView?
    @Published var humidity: PlantSensorCardView?
    @Published var loading: LoadingSkeletonView? = LoadingSkeletonView()
    @Published var error: PlantMonitorErrorView?
}
