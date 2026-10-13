import Foundation
import PlantShared

@MainActor
public final class PeripheralPlantDeviceScanLoader: PlantDeviceScanLoader {
    private let client: PeripheralConnectionClient

    public init(client: PeripheralConnectionClient) {
        self.client = client
    }

    public func start(update: @escaping (PlantDeviceCandidate) -> Void) {
        client.scan { advertisement in
            if let candidate = PlantDeviceCandidateMapper.map(advertisement) {
                update(candidate)
            }
        }
    }

    public func stop() {
        client.stopScan()
    }
}
