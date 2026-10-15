import Foundation
import OSLog
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
    private var watering: WateringWindow?
    private static let logger = Logger(subsystem: "TalkingPlant", category: "watered")

    /// Opened by a Water tap: the moisture to beat and when the chance ends.
    private struct WateringWindow {
        let baseline: Double
        var deadline: Date
    }

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
    /// Fires once when a reading shows the plant was watered after a Water tap.
    public var loadedWatered: (() -> Void)?
    public var loadedSky: Observer<(sky: PlantMonitorSkyViewModel, isGradual: Bool)>?
    /// The bubble's final line, once per speech key: the generated line, or the template when generating fails.
    public var loadedSpokenLine: Observer<PlantMonitorSpokenLine>?
    /// The Sprout button's accessibility label.
    public let hearLabel: String

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
        self.hearLabel = String(format: String.localised(key: "plant.monitor.sprout.hear.label"), plantName)
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
                self?.checkWatered(with: reading)
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
        openWateringWindow()
        actionHandler(.waterTap)
    }

    public func settingsTap() {
        actionHandler(.settingsTap)
    }

    /// A tap while a window is open extends it and keeps its baseline. Otherwise (none, or an expired one) it starts fresh.
    private func openWateringWindow() {
        let now = clock()
        let deadline = now.addingTimeInterval(PlantWateringCheck.window)
        if var open = watering, now <= open.deadline {
            open.deadline = deadline
            watering = open
            Self.logger.debug("watered: window extended (baseline \(open.baseline))")
            return
        }
        watering = nil
        guard let baseline = latestReading?.moisture else { return }
        watering = WateringWindow(baseline: baseline, deadline: deadline)
        Self.logger.debug("watered: window opened (baseline \(baseline))")
    }

    private func checkWatered(with reading: PlantReading) {
        guard let open = watering else { return }
        guard clock() <= open.deadline else {
            watering = nil
            Self.logger.debug("watered: window closed (expired)")
            return
        }
        guard let moisture = reading.moisture else { return }
        let fired = PlantWateringCheck.isWatered(baseline: open.baseline, current: moisture)
        Self.logger.debug("watered: baseline \(open.baseline), reading \(moisture), \(fired ? "fired" : "not fired")")
        guard fired else { return }
        watering = nil
        Self.logger.debug("watered: window closed (fired)")
        loadedWatered?()
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
        let isSleeping = scene.isSleeping
        speechLoader.load(mood: mood, isSleeping: isSleeping, reading: scene.reading) { [weak self] result in
            guard let self, self.speechKey == key else { return }
            var final = speech
            if case .success(let line) = result {
                final = line
                self.loadedSpeech?(line)
            }
            self.loadedSpokenLine?(PlantMonitorSpokenLine(text: final, mood: mood, isSleeping: isSleeping))
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
