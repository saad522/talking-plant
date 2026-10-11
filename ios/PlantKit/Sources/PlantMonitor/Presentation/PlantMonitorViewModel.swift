import Foundation
import PlantShared

@MainActor
public final class PlantMonitorViewModel {
    public typealias Observer<T> = (T) -> Void

    private let loader: PlantReadingLoader
    private let healthLoader: PlantHealthLoader
    private let actionHandler: (PlantMonitorAction) -> Void
    private var appeared: Bool = false
    private var latestReading: PlantReading?
    private var latestMood: PlantMood?

    public let historyLabel: String = String.localised(key: "plant.monitor.history.label")
    public let waterLabel: String = String.localised(key: "plant.monitor.water.label")
    public let talkLabel: String

    public var loadedReading: Observer<PlantReading>?
    public var loadedError: Observer<Error>?
    public var loadedMood: Observer<PlantMood>?
    /// Delivered after every reading and every mood, built from the latest of both.
    public var loadedScene: Observer<PlantMonitorSceneViewModel>?

    public init(
        loader: PlantReadingLoader,
        healthLoader: PlantHealthLoader,
        plantName: String,
        actionHandler: @escaping (PlantMonitorAction) -> Void
    ) {
        self.talkLabel = String(format: String.localised(key: "plant.monitor.talk.label"), plantName)
        self.loader = loader
        self.healthLoader = healthLoader
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
        loadedScene?(PlantMonitorSceneViewModel(reading: latestReading, mood: latestMood))
    }

    /// A failed load keeps the last mood. Reading errors have their own UI.
    private func loadHealth() {
        healthLoader.load { [weak self] result in
            if case .success(let health) = result {
                self?.latestMood = health.mood
                self?.loadedMood?(health.mood)
                self?.loadScene()
            }
        }
    }
}
