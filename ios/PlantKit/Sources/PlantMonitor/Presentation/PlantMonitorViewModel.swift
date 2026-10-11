import Foundation
import PlantShared

@MainActor
public final class PlantMonitorViewModel {
    public typealias Observer<T> = (T) -> Void

    private let loader: PlantReadingLoader
    private let healthLoader: PlantHealthLoader
    private let actionHandler: (PlantMonitorAction) -> Void
    private var appeared: Bool = false

    public let historyLabel: String = String.localised(key: "plant.monitor.history.label")

    public var loadedReading: Observer<PlantReading>?
    public var loadedError: Observer<Error>?
    public var loadedMood: Observer<PlantMood>?

    public init(
        loader: PlantReadingLoader,
        healthLoader: PlantHealthLoader,
        actionHandler: @escaping (PlantMonitorAction) -> Void
    ) {
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
                self?.loadedReading?(reading)
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

    /// A failed load keeps the last mood. Reading errors have their own UI.
    private func loadHealth() {
        healthLoader.load { [weak self] result in
            if case .success(let health) = result {
                self?.loadedMood?(health.mood)
            }
        }
    }
}
