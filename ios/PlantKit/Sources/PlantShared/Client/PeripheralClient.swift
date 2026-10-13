import Foundation

@MainActor
public protocol PeripheralClient {
    typealias Result = Swift.Result<Data, Error>
    typealias WriteResult = Error?

    func read(_ characteristic: PlantCharacteristic, completion: @escaping (Result) -> Void)
    /// Real client: the handler stays registered for the client's lifetime and notifications are
    /// re-enabled on every connection. Disconnects are reported by `PeripheralConnectionClient`, not here.
    func subscribe(to characteristic: PlantCharacteristic, update: @escaping (Result) -> Void)
    func write(_ data: Data, to characteristic: PlantCharacteristic, completion: @escaping (WriteResult) -> Void)
}
