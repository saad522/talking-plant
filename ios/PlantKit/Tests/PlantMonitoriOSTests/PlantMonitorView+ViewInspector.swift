import PlantMonitoriOS
import SwiftUI
import ViewInspector

extension PlantMonitorView where Face == FaceStub {
    var isLoading: Bool {
        (try? inspect().find(LoadingSkeletonView.self)) != nil
    }

    var title: String? {
        try? inspect().find(PlantMonitorHeaderView.self).actualView().title
    }

    var subtitle: String? {
        try? inspect().find(PlantMonitorHeaderView.self).actualView().subtitle
    }

    var settingsLabel: String? {
        try? inspect().find(PlantMonitorHeaderView.self).actualView().settingsLabel
    }

    func simulateTapOnSettings() {
        try? inspect().find(PlantMonitorHeaderView.self).find(ViewType.Button.self).tap()
    }

    var bubbleText: String? {
        try? inspect().find(PlantSpeechBubbleView.self).actualView().text
    }

    var celestial: PlantMonitorWindowView.Celestial? {
        try? inspect().find(PlantMonitorWindowView.self).actualView().celestial
    }

    var skyProgress: Double? {
        try? inspect().find(PlantMonitorWindowView.self).actualView().progress
    }

    var skyIsGradual: Bool? {
        try? inspect().find(PlantMonitorWindowView.self).actualView().isGradual
    }

    var sproutLabel: String? {
        try? inspect().find(ViewType.Button.self, where: { (try? $0.find(FaceStub.self)) != nil }).accessibilityLabel().string()
    }

    func simulateTapOnSprout() {
        try? inspect().find(ViewType.Button.self, where: { (try? $0.find(FaceStub.self)) != nil }).tap()
    }

    func simulateAppear() {
        try? inspect().scrollView().callOnAppear()
    }

    func simulateTap(onButton title: String) {
        let button = try? inspect().findAll(PlantMonitorButtonView.self)
            .first { (try? $0.actualView().title) == title }
        try? button?.find(ViewType.Button.self).tap()
    }

    func renderedChips() -> [PlantSensorChipView] {
        (try? inspect().findAll(PlantSensorChipView.self).map { try $0.actualView() }) ?? []
    }

    func renderedButtons() -> [PlantMonitorButtonView] {
        (try? inspect().findAll(PlantMonitorButtonView.self).map { try $0.actualView() }) ?? []
    }

    func renderedError() -> PlantMonitorErrorView? {
        try? inspect().find(PlantMonitorErrorView.self).actualView()
    }

    func renderedFace() -> FaceStub? {
        try? inspect().find(FaceStub.self).actualView()
    }
}
