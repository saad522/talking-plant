import Foundation

public struct PeripheralAdvertisement: Equatable, Sendable {
    public let identifier: UUID
    public let localName: String?
    public let rssi: Int

    public init(identifier: UUID, localName: String?, rssi: Int) {
        self.identifier = identifier
        self.localName = localName
        self.rssi = rssi
    }
}

public enum PeripheralConnectionState: Equatable, Sendable {
    case unsupported      // no BLE on this device
    case unauthorized     // permission denied or restricted
    case poweredOff
    case idle             // nothing to connect to
    case connecting       // pending connect, or connected but still discovering
    case connected        // service + 3 characteristics ready, Readings notify on
    case incompatible     // connected but the Plant Service or a characteristic is missing
}

@MainActor
public protocol PeripheralConnectionClient {
    /// Delivers the current state immediately, then every change.
    func subscribe(state update: @escaping (PeripheralConnectionState) -> Void)
    /// Advertisements of the Plant Service, repeated (RSSI updates) until `stopScan()`.
    func scan(update: @escaping (PeripheralAdvertisement) -> Void)
    func stopScan()
    /// Connects and keeps reconnecting until `disconnect()`. `name` is the fallback
    /// when the identifier is unknown to this phone.
    func connect(to identifier: UUID, name: String)
    /// Cancels the connection and stops reconnecting.
    func disconnect()
}
