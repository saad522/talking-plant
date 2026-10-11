import PlantMonitoriOS
import SwiftUI
import ViewInspector

extension PlantMonitorView where Face == FaceStub {
    var isLoading: Bool {
        (try? inspect().find(LoadingSkeletonView.self)) != nil
    }

    var historyLabel: String? {
        try? inspect().find(ViewType.Button.self).labelView().text().string()
    }

    func simulateAppear() {
        try? inspect().scrollView().callOnAppear()
    }

    func simulateHistoryTap() {
        try? inspect().find(ViewType.Button.self).tap()
    }

    func renderedCards() -> [PlantSensorCardView] {
        (try? inspect().findAll(PlantSensorCardView.self).map { try $0.actualView() }) ?? []
    }

    func renderedError() -> PlantMonitorErrorView? {
        try? inspect().find(PlantMonitorErrorView.self).actualView()
    }

    func renderedFace() -> FaceStub? {
        try? inspect().find(FaceStub.self).actualView()
    }

    func renderedMoodLabel() -> String? {
        try? inspect().find(PlantMoodView<FaceStub>.self).vStack().text(1).string()
    }
}
