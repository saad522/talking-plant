import Foundation
import PlantMonitor
import PlantShared
import SwiftUI

@MainActor
public enum PlantMonitorUIComposer {
    public static func composed<Face: View>(
        with loader: PlantReadingLoader,
        healthLoader: PlantHealthLoader,
        connectionLoader: PlantConnectionLoader,
        speechLoader: PlantSpeechLoader,
        plantName: String,
        room: String,
        lastScene: PlantLastSceneStore,
        face: @escaping (PlantMood, _ isSurprised: Bool) -> Face,
        haptics: PlantHapticsClient,
        sounds: PlantSoundEffectsClient,
        voice: PlantMonitorVoice,
        spokenLines: PlantSpokenLineStore,
        speaksLines: @escaping () -> Bool,
        clock: @escaping () -> Date,
        schedule: @escaping SimulatedPeripheralClient.Schedule,
        shakeLoader: PlantShakeLoader,
        randomIndex: @escaping (Int) -> Int,
        actionHandler: @escaping (PlantMonitorAction) -> Void
    ) -> PlantMonitorView<Face> {
        let calendar = Calendar.current
        let store = PlantMonitorStore<Face>(
            scene: lastScene.scene,
            sky: PlantMonitorSkyViewModel(scene: lastScene.scene, date: clock(), calendar: calendar)
        )
        let viewModel = PlantMonitorViewModel(
            loader: loader,
            healthLoader: healthLoader,
            connectionLoader: connectionLoader,
            speechLoader: speechLoader,
            plantName: plantName,
            clock: clock,
            calendar: calendar,
            schedule: schedule,
            actionHandler: actionHandler
        )

        let sprout = PlantMonitorSproutViewModel(
            voice: voice,
            spokenLines: spokenLines,
            isEnabled: speaksLines,
            clock: clock,
            calendar: calendar,
            schedule: schedule,
            shakeLoader: shakeLoader,
            randomIndex: randomIndex
        )
        store.sproutLabel = viewModel.hearLabel
        store.sproutTap = { [weak sprout] in sprout?.sproutTap() }

        let header = PlantMonitorHeaderViewModel(name: plantName, room: room, mood: nil)
        store.title = header.title
        store.subtitle = header.subtitle

        viewModel.loadedReading = { [weak store] _ in
            store?.loading = nil
            store?.error = nil
        }

        viewModel.loadedScene = { [weak store, weak viewModel] scene in
            lastScene.save(scene.scene)
            store?.palette = PlantMonitorStore<Face>.makePalette(for: scene.scene)
            store?.subtitle = scene.header(name: plantName, room: room).subtitle
            if let faceMood = scene.faceMood, let store {
                store.faceMood = faceMood
                store.face = face(faceMood, store.isSurprised)
            }
            store?.chips = makeChips(for: scene)
            let buttons = makeButtons(isWaterPrimary: scene.isWaterPrimary, viewModel: viewModel, haptics: haptics)
            store?.primaryButton = buttons.primary
            store?.secondaryButtons = buttons.secondary
        }

        sprout.loadedSurprised = { [weak store] isSurprised in
            guard let store else { return }
            store.isSurprised = isSurprised
            if let faceMood = store.faceMood {
                store.face = face(faceMood, isSurprised)
            }
            if isSurprised {
                store.shakeCount += 1
                haptics.play(.bump)
                sounds.play(.pop)
            }
        }

        viewModel.loadedWatered = {
            haptics.play(.success)
            sounds.play(.chime)
        }

        viewModel.loadedSpokenLine = { [weak sprout] line in
            sprout?.lineSettled(line)
        }

        viewModel.loadedSky = { [weak store] update in
            store?.window = PlantMonitorStore<Face>.makeWindow(sky: update.sky, isGradual: update.isGradual)
        }

        viewModel.loadedSpeech = { [weak store] speech in
            store?.bubble = PlantSpeechBubbleView(text: speech)
        }

        viewModel.loadedError = { [weak store] error in
            store?.loading = nil
            store?.error = makeError(for: error, haptics: haptics, actionHandler: actionHandler)
        }

        return PlantMonitorView(
            store: store,
            viewModel: viewModel,
            sprout: sprout,
            settingsAction: { [weak viewModel] in
                haptics.play(.tap)
                viewModel?.settingsTap()
            }
        )
    }

    /// The home screen's background colour for a scene, for hand-offs from outside the feature.
    public static func background(for scene: PlantMonitorScene) -> Color {
        PlantMonitorStore<EmptyView>.makePalette(for: scene).background
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

    /// Water leads while the plant is thirsty, Talk otherwise. History is always secondary.
    private static func makeButtons(
        isWaterPrimary: Bool,
        viewModel: PlantMonitorViewModel?,
        haptics: PlantHapticsClient
    ) -> (primary: PlantMonitorButtonView, secondary: [PlantMonitorButtonView]) {
        let talk = { (style: PlantMonitorButtonView.Style) in
            PlantMonitorButtonView(
                title: viewModel?.talkLabel ?? "",
                systemImage: "mic.fill",
                style: style,
                accent: \.primary,
                action: { [weak viewModel] in
                    haptics.play(.tap)
                    viewModel?.talkTap()
                }
            )
        }
        let water = { (style: PlantMonitorButtonView.Style) in
            PlantMonitorButtonView(
                title: viewModel?.waterLabel ?? "",
                systemImage: "drop.fill",
                style: style,
                accent: \.water,
                action: { [weak viewModel] in
                    haptics.play(.tap)
                    viewModel?.waterTap()
                }
            )
        }
        let history = PlantMonitorButtonView(
            title: viewModel?.historyLabel ?? "",
            systemImage: "chart.xyaxis.line",
            style: .secondary,
            accent: \.ink,
            action: { [weak viewModel] in
                haptics.play(.tap)
                viewModel?.historyTap()
            }
        )
        return isWaterPrimary
            ? (water(.primary), [talk(.secondary), history])
            : (talk(.primary), [water(.secondary), history])
    }

    private static func makeError(
        for error: Error,
        haptics: PlantHapticsClient,
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

        return PlantMonitorErrorView(
            store: store,
            viewModel: viewModel,
            tap: { [weak viewModel] in
                haptics.play(.tap)
                viewModel?.tap()
            }
        )
    }
}
