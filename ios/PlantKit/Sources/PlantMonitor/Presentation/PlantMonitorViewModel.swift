import Foundation
import PlantShared

@MainActor
public final class PlantMonitorViewModel {
    public typealias Observer<T> = (T) -> Void

    private let loader: PlantReadingLoader
    private let healthLoader: PlantHealthLoader
    private let speechLoader: PlantSpeechLoader
    private let actionHandler: (PlantMonitorAction) -> Void
    private var appeared: Bool = false
    private var latestReading: PlantReading?
    private var latestMood: PlantMood?
    private var speechKey: SpeechKey?

    /// A new line is only asked for when the mood or the scene changes.
    private struct SpeechKey: Equatable {
        let mood: PlantMood
        let scene: PlantMonitorScene
    }

    public let historyLabel: String = String.localised(key: "plant.monitor.history.label")
    public let waterLabel: String = String.localised(key: "plant.monitor.water.label")
    public let talkLabel: String

    public var loadedReading: Observer<PlantReading>?
    public var loadedError: Observer<Error>?
    /// Delivered after every reading and every mood, built from the latest of both.
    public var loadedScene: Observer<PlantMonitorSceneViewModel>?
    /// The template line first, then the generated one when it arrives.
    public var loadedSpeech: Observer<String>?

    public init(
        loader: PlantReadingLoader,
        healthLoader: PlantHealthLoader,
        speechLoader: PlantSpeechLoader,
        plantName: String,
        actionHandler: @escaping (PlantMonitorAction) -> Void
    ) {
        self.talkLabel = String(format: String.localised(key: "plant.monitor.talk.label"), plantName)
        self.loader = loader
        self.healthLoader = healthLoader
        self.speechLoader = speechLoader
        self.actionHandler = actionHandler
    }

    public func appear() {
        guard appeared == false else { return }
        appeared = true
        loader.subscribe { [weak self] result in
            switch result {
            case .success(let reading):
                self?.latestReading = reading
                self?.loadedReading?(reading)
                self?.loadScene()
            case .failure(let error):
                self?.loadedError?(error)
            }
        }
        loadHealth()
        healthLoader.subscribe { [weak self] in
            self?.loadHealth()
        }
    }

    public func historyTap() {
        actionHandler(.historyTap)
    }

    public func talkTap() {
        actionHandler(.talkTap)
    }

    public func waterTap() {
        actionHandler(.waterTap)
    }

    private func loadScene() {
        let scene = PlantMonitorSceneViewModel(reading: latestReading, mood: latestMood)
        loadedScene?(scene)
        loadSpeech(for: scene)
    }

    /// A failed load keeps the template line. A result for an old key is dropped.
    private func loadSpeech(for scene: PlantMonitorSceneViewModel) {
        guard let mood = scene.mood, let speech = scene.speech else { return }
        let key = SpeechKey(mood: mood, scene: scene.scene)
        guard key != speechKey else { return }
        speechKey = key
        loadedSpeech?(speech)
        speechLoader.load(mood: mood, isSleeping: scene.isSleeping, reading: scene.reading) { [weak self] result in
            if case .success(let line) = result, self?.speechKey == key {
                self?.loadedSpeech?(line)
            }
        }
    }

    /// A failed load keeps the last mood. Reading errors have their own UI.
    private func loadHealth() {
        healthLoader.load { [weak self] result in
            if case .success(let health) = result {
                self?.latestMood = health.mood
                self?.loadScene()
            }
        }
    }
}
