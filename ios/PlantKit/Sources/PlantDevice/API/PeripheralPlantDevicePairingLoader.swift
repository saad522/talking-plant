import Foundation
import PlantShared

@MainActor
public final class PeripheralPlantDevicePairingLoader: PlantDevicePairingLoader {
    private let client: PeripheralConnectionClient
    private let settings: PlantDeviceSettings
    private var subscriptions: [(PlantPairedDevice?) -> Void] = []

    public init(client: PeripheralConnectionClient, settings: PlantDeviceSettings) {
        self.client = client
        self.settings = settings
    }

    public func subscribe(update: @escaping (PlantPairedDevice?) -> Void) {
        subscriptions.append(update)
        update(settings.loadPairedDevice())
    }

    public func pair(_ candidate: PlantDeviceCandidate) {
        let device = PlantPairedDevice(identifier: candidate.identifier, name: candidate.name)
        settings.savePairedDevice(device)
        client.connect(to: device.identifier, name: device.name)
        subscriptions.forEach { $0(device) }
    }

    public func forget() {
        settings.clearPairedDevice()
        client.disconnect()
        subscriptions.forEach { $0(nil) }
    }

    public func connectSaved() {
        guard let device = settings.loadPairedDevice() else { return }
        client.connect(to: device.identifier, name: device.name)
    }
}
