import Foundation

@MainActor
public protocol PeripheralClient {
    typealias Result = Swift.Result<Data, Error>
    typealias WriteResult = Error?

    func read(_ characteristic: PlantCharacteristic, completion: @escaping (Result) -> Void)
    func subscribe(to characteristic: PlantCharacteristic, update: @escaping (Result) -> Void)
    func write(_ data: Data, to characteristic: PlantCharacteristic, completion: @escaping (WriteResult) -> Void)
}
