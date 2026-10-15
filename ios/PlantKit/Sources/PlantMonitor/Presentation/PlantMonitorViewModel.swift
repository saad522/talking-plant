import Foundation
import PlantShared

@MainActor
public final class PlantMonitorViewModel {
    public typealias Observer<T> = (T) -> Void

    private let loader: PlantReadingLoader
    private let healthLoader: PlantHealthLoader
    private let connectionLoader: PlantConnectionLoader
    private let speechLoader: PlantSpeechLoader
    private let clock: () -> Date
    private let calendar: Calendar
    private let schedule: SimulatedPeripheralClient.Schedule
    private let actionHandler: (PlantMonitorAction) -> Void
    private var latestSky: PlantMonitorSkyViewModel?
    private var latestScene: PlantMonitorScene?
    private var appeared: Bool = false
    private var latestReading: PlantReading?
    private var latestMood: PlantMood?
    private var latestConnection: PlantConnection?
    private var speechKey: SpeechKey?

    /// A new line is only asked for when the mood or the scene changes.
    private struct SpeechKey: Equatable {
        let mood: PlantMood
        let scene: PlantMonitorScene
    }

    /// The sky moves a little each tick. A bigger step than this is a jump.
    private static let gradualProgress = 0.01
    private static let skyInterval: TimeInterval = 60

    public let historyLabel: String = String.localised(key: "plant.monitor.history.label")
    public let waterLabel: String = String.localised(key: "plant.monitor.water.label")
    public let settingsLabel: String = String.localised(key: "plant.monitor.settings.label")
    public let talkLabel: String

    public var loadedReading: Observer<PlantReading>?
    public var loadedError: Observer<Error>?
    /// Delivered after every reading and every mood, built from the latest of both.
    public var loadedScene: Observer<PlantMonitorSceneViewModel>?
    /// The template line first, then the generated one when it arrives.
    public var loadedSpeech: Observer<String>?
    /// The sun or moon and where it sits on its arc, with whether the move from the last one is small.
    public var loadedSky: Observer<(sky: PlantMonitorSkyViewModel, isGradual: Bool)>?

    public init(
        loader: PlantReadingLoader,
        healthLoader: PlantHealthLoader,
        connectionLoader: PlantConnectionLoader,
        speechLoader: PlantSpeechLoader,
        plantName: String,
        clock: @escaping () -> Date,
        calendar: Calendar,
        schedule: @escaping SimulatedPeripheralClient.Schedule,
        actionHandler: @escaping (PlantMonitorAction) -> Void
    ) {
        self.talkLabel = String(format: String.localised(key: "plant.monitor.talk.label"), plantName)
        self.loader = loader
        self.healthLoader = healthLoader
        self.connectionLoader = connectionLoader
        self.speechLoader = speechLoader
        self.clock = clock
        self.calendar = calendar
        self.schedule = schedule
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
        schedule(Self.skyInterval) { [weak self] in
            guard let self else { return false }
            self.loadSky()
            return true
        }
        loadHealth()
        healthLoader.subscribe { [weak self] in
            self?.loadHealth()
        }
        connectionLoader.subscribe { [weak self] connection in
            self?.latestConnection = connection
            self?.loadScene()
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

    public func settingsTap() {
        actionHandler(.settingsTap)
    }

    private func loadScene() {
        let scene = PlantMonitorSceneViewModel(reading: latestReading, mood: latestMood, connection: latestConnection)
        loadedScene?(scene)
        latestScene = scene.scene
        loadSky()
        loadSpeech(for: scene)
    }

    /// Nothing until a scene is known, so the remembered sky stays until then.
    private func loadSky() {
        guard let scene = latestScene else { return }
        let sky = PlantMonitorSkyViewModel(scene: scene, date: clock(), calendar: calendar)
        let isGradual = latestSky.map { $0.body == sky.body && abs(sky.progress - $0.progress) <= Self.gradualProgress } ?? false
        latestSky = sky
        loadedSky?((sky, isGradual))
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
