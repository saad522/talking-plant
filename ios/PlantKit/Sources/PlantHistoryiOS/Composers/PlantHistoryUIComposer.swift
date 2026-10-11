import PlantHistory
import SwiftUI

@MainActor
public enum PlantHistoryUIComposer {
    public static func composed(with loader: PlantHistoryLoader) -> PlantHistoryView {
        let store = PlantHistoryStore()
        let viewModel = PlantHistoryViewModel(loader: loader)

        viewModel.loadedRange = { [weak store] range in
            store?.selectedRange = range
        }

        viewModel.loadedSamples = { [weak store] samples in
            store?.loading = nil
            store?.message = nil
            store?.moisture = makeChart(.moisture, samples: samples)
            store?.light = makeChart(.light, samples: samples)
            store?.temperature = makeChart(.temperature, samples: samples)
            store?.humidity = makeChart(.humidity, samples: samples)
        }

        viewModel.loadedEmpty = { [weak store] description in
            store?.loading = nil
            store?.clearCharts()
            store?.message = PlantHistoryMessageView(icon: Image(systemName: "chart.xyaxis.line"), text: description)
        }

        viewModel.loadedError = { [weak store] description in
            store?.loading = nil
            store?.message = PlantHistoryMessageView(icon: Image(systemName: "exclamationmark.triangle"), text: description)
        }

        return PlantHistoryView(store: store, viewModel: viewModel)
    }

    private static func makeChart(_ metric: PlantHistoryMetric, samples: [PlantHistorySample]) -> PlantHistoryChartView {
        PlantHistoryChartView(viewModel: PlantHistoryChartViewModel(metric: metric, samples: samples))
    }
}

private extension PlantHistoryStore {
    func clearCharts() {
        moisture = nil
        light = nil
        temperature = nil
        humidity = nil
    }
}
