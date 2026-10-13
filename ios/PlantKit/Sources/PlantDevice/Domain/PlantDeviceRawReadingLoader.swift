import Foundation

@MainActor
public protocol PlantDeviceRawReadingLoader {
    typealias Result = Swift.Result<PlantDeviceRawReading, Error>

    func load(completion: @escaping (Result) -> Void)
    func subscribe(update: @escaping (Result) -> Void)
}
