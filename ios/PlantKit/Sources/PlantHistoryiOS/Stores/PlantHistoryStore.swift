import PlantHistory
import SwiftUI

@MainActor
final class PlantHistoryStore: ObservableObject {
    @Published var selectedRange: PlantHistoryRange = .day
    @Published var moisture: PlantHistoryChartView?
    @Published var light: PlantHistoryChartView?
    @Published var temperature: PlantHistoryChartView?
    @Published var humidity: PlantHistoryChartView?
    @Published var loading: PlantHistoryLoadingView? = PlantHistoryLoadingView()
    @Published var message: PlantHistoryMessageView?
}
