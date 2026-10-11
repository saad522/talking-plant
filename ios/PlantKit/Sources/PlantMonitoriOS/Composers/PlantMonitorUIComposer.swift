import PlantMonitor
import PlantShared
import SwiftUI

@MainActor
public enum PlantMonitorUIComposer {
    public static func composed<Face: View>(
        with loader: PlantReadingLoader,
        healthLoader: PlantHealthLoader,
        plantName: String,
        room: String,
        face: @escaping (PlantMood) -> Face,
        actionHandler: @escaping (PlantMonitorAction) -> Void
    ) -> PlantMonitorView<Face> {
        let store = PlantMonitorStore<Face>()
        let viewModel = PlantMonitorViewModel(
            loader: loader,
            healthLoader: healthLoader,
            plantName: plantName,
            actionHandler: actionHandler
        )

        let header = PlantMonitorHeaderViewModel(name: plantName, room: room, mood: nil)
        store.title = header.title
        store.subtitle = header.subtitle

        viewModel.loadedReading = { [weak store] _ in
            store?.loading = nil
            store?.error = nil
        }

        viewModel.loadedScene = { [weak store, weak viewModel] scene in
            store?.palette = palette(for: scene.scene)
            if let faceMood = scene.faceMood, let speech = scene.speech {
                store?.subtitle = scene.header(name: plantName, room: room).subtitle
                store?.face = face(faceMood)
                store?.bubble = PlantSpeechBubbleView(text: speech)
            }
            store?.window = PlantMonitorWindowView(celestial: scene.scene == .night ? .moon : .sun)
            store?.chips = makeChips(for: scene)
            let buttons = makeButtons(for: scene.scene, viewModel: viewModel)
            store?.primaryButton = buttons.primary
            store?.secondaryButtons = buttons.secondary
        }

        viewModel.loadedError = { [weak store] error in
            store?.loading = nil
            store?.error = makeError(for: error, actionHandler: actionHandler)
        }

        return PlantMonitorView(store: store, viewModel: viewModel)
    }

    private static func palette(for scene: PlantMonitorScene) -> PlantMonitorPalette {
        switch scene {
        case .day: .day
        case .thirsty: .thirsty
        case .night: .night
        }
    }

    private static func makeChips(for scene: PlantMonitorSceneViewModel) -> [PlantSensorChipView] {
        guard let reading = scene.reading else { return [] }
        return scene.sensors.map { kind in
            PlantSensorChipView(
                kind: kind,
                viewModel: PlantSensorCardViewModel(kind: kind, reading: reading),
                isWarning: scene.warnings.contains(kind)
            )
        }
    }

    /// Water leads in the thirsty scene, Talk otherwise. History is always secondary.
    private static func makeButtons(
        for scene: PlantMonitorScene,
        viewModel: PlantMonitorViewModel?
    ) -> (primary: PlantMonitorButtonView, secondary: [PlantMonitorButtonView]) {
        let talk = { (style: PlantMonitorButtonView.Style) in
            PlantMonitorButtonView(
                title: viewModel?.talkLabel ?? "",
                systemImage: "mic.fill",
                style: style,
                accent: \.primary,
                action: { [weak viewModel] in viewModel?.talkTap() }
            )
        }
        let water = { (style: PlantMonitorButtonView.Style) in
            PlantMonitorButtonView(
                title: viewModel?.waterLabel ?? "",
                systemImage: "drop.fill",
                style: style,
                accent: \.water,
                action: { [weak viewModel] in viewModel?.waterTap() }
            )
        }
        let history = PlantMonitorButtonView(
            title: viewModel?.historyLabel ?? "",
            systemImage: "chart.xyaxis.line",
            style: .secondary,
            accent: \.ink,
            action: { [weak viewModel] in viewModel?.historyTap() }
        )
        return scene == .thirsty
            ? (water(.primary), [talk(.secondary), history])
            : (talk(.primary), [water(.secondary), history])
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
