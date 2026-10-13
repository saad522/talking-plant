import Foundation
import PlantShared

@MainActor
public protocol PlantDeviceConnectionLoader {
    /// Delivers the current connection immediately, then every change.
    func subscribe(update: @escaping (PlantConnection) -> Void)
}
