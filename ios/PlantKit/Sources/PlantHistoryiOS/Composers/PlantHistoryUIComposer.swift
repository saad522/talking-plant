import PlantHistory
import PlantShared
import SwiftUI

@MainActor
public enum PlantHistoryUIComposer {
    public static func composed(with loader: PlantHistoryLoader, haptics: PlantHapticsClient) -> PlantHistoryView {
        let store = PlantHistoryStore()
        let viewModel = PlantHistoryViewModel(loader: loader)

        viewModel.loadedRange = { [weak store] range in
            store?.selectedRange = range
        }

        viewModel.loadedSamples = { [weak store] samples in
            guard let store else { return }
            // loadedRange always arrives before the samples for that range.
            let range = store.selectedRange
            store.loading = nil
            store.message = nil
            store.moisture = makeChart(.moisture, samples: samples, range: range)
            store.light = makeChart(.light, samples: samples, range: range)
            store.temperature = makeChart(.temperature, samples: samples, range: range)
            store.humidity = makeChart(.humidity, samples: samples, range: range)
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

        return PlantHistoryView(
            store: store,
            viewModel: viewModel,
            select: { [weak viewModel] in
                haptics.play(.selection)
                viewModel?.select($0)
            }
        )
    }

    private static func makeChart(
        _ metric: PlantHistoryMetric,
        samples: [PlantHistorySample],
        range: PlantHistoryRange
    ) -> PlantHistoryChartView {
        PlantHistoryChartView(viewModel: PlantHistoryChartViewModel(metric: metric, samples: samples, range: range))
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
