import Foundation

@MainActor
public protocol PlantDeviceScanLoader {
    /// Delivers every sighting of a plant sensor, repeated as the signal changes, until `stop()`.
    func start(update: @escaping (PlantDeviceCandidate) -> Void)
    func stop()
}
