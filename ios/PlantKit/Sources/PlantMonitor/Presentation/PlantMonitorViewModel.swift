import Foundation
import PlantShared

@MainActor
public final class PlantMonitorViewModel {
    public typealias Observer<T> = (T) -> Void

    private let loader: PlantReadingLoader
    private let actionHandler: (PlantMonitorAction) -> Void
    private var appeared: Bool = false

    public let historyLabel: String = String.localised(key: "plant.monitor.history.label")

    public var loadedReading: Observer<PlantReading>?
    public var loadedError: Observer<Error>?

    public init(loader: PlantReadingLoader, actionHandler: @escaping (PlantMonitorAction) -> Void) {
        self.loader = loader
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
    }

    public func historyTap() {
        actionHandler(.historyTap)
    }
}
