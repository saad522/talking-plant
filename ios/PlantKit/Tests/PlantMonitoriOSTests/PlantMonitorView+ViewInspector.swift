import PlantMonitoriOS
import SwiftUI
import ViewInspector

extension PlantMonitorView {
    var isLoading: Bool {
        (try? inspect().find(LoadingSkeletonView.self)) != nil
    }

    var historyLabel: String? {
        try? inspect().scrollView().vStack().button(1).labelView().text().string()
    }

    func simulateAppear() {
        try? inspect().scrollView().callOnAppear()
    }

    func simulateHistoryTap() {
        try? inspect().scrollView().vStack().button(1).tap()
    }

    func renderedCards() -> [PlantSensorCardView] {
        (try? inspect().findAll(PlantSensorCardView.self).map { try $0.actualView() }) ?? []
    }

    func renderedError() -> PlantMonitorErrorView? {
        try? inspect().find(PlantMonitorErrorView.self).actualView()
    }
}
