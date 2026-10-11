import Foundation

@MainActor
public final class PlantMonitorErrorViewModel {
    public typealias Observer<T> = (T) -> Void

    private let error: Error
    private let actionHandler: (PlantMonitorAction) -> Void

    public var loadedConnection: Observer<Void>?
    public var loadedGeneral: Observer<Void>?

    public let description: String
    public let buttonTitle: String = String.localised(key: "plant.monitor.error.dismiss.label")

    public init(error: Error, actionHandler: @escaping (PlantMonitorAction) -> Void) {
        self.error = error
        self.actionHandler = actionHandler
        self.description = switch error {
        case PeripheralPlantReadingLoader.Error.connectivity:
            String.localised(key: "plant.monitor.connectivity.error.description")
        default:
            String.localised(key: "plant.monitor.general.error.description")
        }
    }

    public func appear() {
        switch error {
        case PeripheralPlantReadingLoader.Error.connectivity:
            loadedConnection?(())
        default:
            loadedGeneral?(())
        }
    }

    public func tap() {
        actionHandler(.dismissed)
    }
}
