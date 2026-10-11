import PlantMonitor
import PlantShared
import SwiftUI

@MainActor
public enum PlantMonitorUIComposer {
    public static func composed(
        with loader: PlantReadingLoader,
        actionHandler: @escaping (PlantMonitorAction) -> Void
    ) -> PlantMonitorView {
        let store = PlantMonitorStore()
        let viewModel = PlantMonitorViewModel(loader: loader, actionHandler: actionHandler)

        viewModel.loadedReading = { [weak store] reading in
            store?.loading = nil
            store?.error = nil
            store?.moisture = makeCard(.moisture, reading: reading)
            store?.light = makeCard(.light, reading: reading)
            store?.temperature = makeCard(.temperature, reading: reading)
            store?.humidity = makeCard(.humidity, reading: reading)
        }

        viewModel.loadedError = { [weak store] error in
            store?.loading = nil
            store?.error = makeError(for: error, actionHandler: actionHandler)
        }

        return PlantMonitorView(store: store, viewModel: viewModel)
    }

    private static func makeCard(_ kind: PlantSensorKind, reading: PlantReading) -> PlantSensorCardView {
        PlantSensorCardView(viewModel: PlantSensorCardViewModel(kind: kind, reading: reading))
    }

    private static func makeError(
        for error: Error,
        actionHandler: @escaping (PlantMonitorAction) -> Void
    ) -> PlantMonitorErrorView {
        let store = PlantMonitorErrorStore()
        let viewModel = PlantMonitorErrorViewModel(error: error, actionHandler: actionHandler)

        viewModel.loadedConnection = { [weak store] _ in
            store?.icon = Image(systemName: "antenna.radiowaves.left.and.right.slash")
        }

        viewModel.loadedGeneral = { [weak store] _ in
            store?.icon = Image(systemName: "exclamationmark.triangle")
        }

        return PlantMonitorErrorView(store: store, viewModel: viewModel)
    }
}
