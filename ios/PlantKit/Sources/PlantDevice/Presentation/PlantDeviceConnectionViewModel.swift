import Foundation
import PlantShared

public final class PlantDeviceConnectionViewModel: Equatable {
    public let label: String
    public let isConnected: Bool
    /// Only when the user can fix it in the Settings app.
    public let showsOpenSettings: Bool

    public init(connection: PlantConnection) {
        label = switch connection {
        case .notPaired: String.localised(key: "plant.device.connection.notPaired.label")
        case .connecting: String.localised(key: "plant.device.connection.connecting.label")
        case .connected: String.localised(key: "plant.device.connection.connected.label")
        case .offline: String.localised(key: "plant.device.connection.offline.label")
        case .bluetoothOff: String.localised(key: "plant.device.connection.bluetoothOff.label")
        case .bluetoothUnauthorized: String.localised(key: "plant.device.connection.bluetoothUnauthorized.label")
        case .bluetoothUnsupported: String.localised(key: "plant.device.connection.bluetoothUnsupported.label")
        case .incompatible: String.localised(key: "plant.device.connection.incompatible.label")
        }
        isConnected = connection == .connected
        showsOpenSettings = connection == .bluetoothUnauthorized
    }

    public static func == (lhs: PlantDeviceConnectionViewModel, rhs: PlantDeviceConnectionViewModel) -> Bool {
        lhs.label == rhs.label && lhs.isConnected == rhs.isConnected && lhs.showsOpenSettings == rhs.showsOpenSettings
    }
}
