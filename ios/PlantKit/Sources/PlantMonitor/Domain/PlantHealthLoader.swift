import Foundation

@MainActor
public protocol PlantHealthLoader {
    typealias Result = Swift.Result<PlantHealth, Error>

    func load(completion: @escaping (Result) -> Void)
    /// Called whenever the health should be evaluated again.
    func subscribe(update: @escaping () -> Void)
}
