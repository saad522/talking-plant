import Foundation

@MainActor
public protocol PlantHistoryLoader {
    typealias Result = Swift.Result<[PlantHistorySample], Error>

    /// Downsampled history for `range`, ending now, oldest first.
    func load(_ range: PlantHistoryRange, completion: @escaping (Result) -> Void)
    /// Called every time the history changes, so the caller can load again.
    func subscribe(update: @escaping () -> Void)
}
