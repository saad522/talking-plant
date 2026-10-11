import Foundation

@MainActor
public protocol PlantReadingStore {
    typealias InsertionResult = Error?
    typealias RetrievalResult = Swift.Result<[PlantReading], Error>

    func insert(_ reading: PlantReading, completion: @escaping (InsertionResult) -> Void)
    /// Readings with `receivedAt` in `start...end`, oldest first.
    func retrieve(from start: Date, to end: Date, completion: @escaping (RetrievalResult) -> Void)
    /// Called after every successful insert.
    func subscribe(update: @escaping () -> Void)
}
