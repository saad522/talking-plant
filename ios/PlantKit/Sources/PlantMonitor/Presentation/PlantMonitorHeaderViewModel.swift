import Foundation
import PlantShared

public final class PlantMonitorHeaderViewModel {
    public let title: String
    /// "<room> · <mood label>" ("Sleeping" while the plant sleeps), or just the room before a mood loads.
    /// Any connection other than connected or unknown replaces the mood with its label.
    public let subtitle: String

    public init(name: String, room: String, mood: PlantMood?, isSleeping: Bool = false, connection: PlantConnection? = nil) {
        self.title = name
        if let connection, let key = Self.labelKey(for: connection) {
            self.subtitle = String(format: String.localised(key: "plant.monitor.header.subtitle"), room, String.localised(key: key))
        } else if let mood {
            self.subtitle = String(
                format: String.localised(key: "plant.monitor.header.subtitle"),
                room,
                isSleeping ? String.localised(key: "plant.monitor.sleeping.label") : PlantMoodViewModel(mood: mood).label
            )
        } else {
            self.subtitle = room
        }
    }

    private static func labelKey(for connection: PlantConnection) -> String? {
        switch connection {
        case .connected: nil
        case .notPaired: "plant.monitor.connection.notPaired.label"
        case .connecting: "plant.monitor.connection.connecting.label"
        case .offline: "plant.monitor.connection.offline.label"
        case .bluetoothOff: "plant.monitor.connection.bluetoothOff.label"
        case .bluetoothUnauthorized: "plant.monitor.connection.bluetoothUnauthorized.label"
        case .bluetoothUnsupported: "plant.monitor.connection.bluetoothUnsupported.label"
        case .incompatible: "plant.monitor.connection.incompatible.label"
        }
    }
}
