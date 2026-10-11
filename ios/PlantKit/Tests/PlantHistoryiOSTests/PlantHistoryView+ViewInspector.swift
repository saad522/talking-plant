import PlantHistory
import PlantHistoryiOS
import SwiftUI
import ViewInspector

extension PlantHistoryView {
    var isLoading: Bool {
        (try? inspect().find(PlantHistoryLoadingView.self)) != nil
    }

    var selectedRange: PlantHistoryRange? {
        try? inspect().find(ViewType.Picker.self).selectedValue(PlantHistoryRange.self)
    }

    var rangeTitles: [String] {
        (try? inspect().find(ViewType.Picker.self).forEach(0).map { try $0.text().string() }) ?? []
    }

    func simulateAppear() {
        try? inspect().scrollView().callOnAppear()
    }

    func simulateSelecting(_ range: PlantHistoryRange) {
        try? inspect().find(ViewType.Picker.self).select(value: range)
    }

    func renderedCharts() -> [PlantHistoryChartView] {
        (try? inspect().findAll(PlantHistoryChartView.self).map { try $0.actualView() }) ?? []
    }

    func renderedMessage() -> PlantHistoryMessageView? {
        try? inspect().find(PlantHistoryMessageView.self).actualView()
    }
}

extension PlantHistoryChartView {
    var title: String? { try? inspect().vStack().hStack(0).text(0).string() }
    var latestValue: String? { try? inspect().vStack().hStack(0).text(2).string() }
}

extension PlantHistoryMessageView {
    var text: String? { try? inspect().zStack().vStack(1).text(1).string() }
}
