import Foundation
import PlantShared

enum PlantDeviceCandidateMapper {
    /// CoreBluetooth reports 127 when the signal strength is unavailable.
    private static let unavailableRSSI = 127

    /// Plant sensors only. The name arrives in the scan response, so an early sighting without one is dropped.
    static func map(_ advertisement: PeripheralAdvertisement) -> PlantDeviceCandidate? {
        guard let name = advertisement.localName,
              name.hasPrefix(PlantBluetoothContract.localNamePrefix),
              advertisement.rssi != unavailableRSSI else { return nil }

        return PlantDeviceCandidate(identifier: advertisement.identifier, name: name, rssi: advertisement.rssi)
    }
}
