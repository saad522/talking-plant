import Foundation

public struct PlantDeviceCandidate: Equatable, Sendable {
    public let identifier: UUID
    public let name: String
    public let rssi: Int

    public init(identifier: UUID, name: String, rssi: Int) {
        self.identifier = identifier
        self.name = name
        self.rssi = rssi
    }
}
