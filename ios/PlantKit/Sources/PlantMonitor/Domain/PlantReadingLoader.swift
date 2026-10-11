import Foundation

@MainActor
public protocol PlantReadingLoader {
    typealias Result = Swift.Result<PlantReading, Error>

    func load(completion: @escaping (Result) -> Void)
    func subscribe(update: @escaping (Result) -> Void)
}
