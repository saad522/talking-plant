import Foundation
import PlantShared

@MainActor
public final class LocalPlantHistoryLoader: PlantHistoryLoader {
    private let store: PlantReadingStore
    private let currentDate: () -> Date

    public enum Error: Swift.Error, Equatable {
        case retrieval
    }

    /// - Parameter currentDate: "Now" for the range. Pass the simulated clock in simulated mode.
    public init(store: PlantReadingStore, currentDate: @escaping () -> Date = Date.init) {
        self.store = store
        self.currentDate = currentDate
    }

    public func load(_ range: PlantHistoryRange, completion: @escaping (PlantHistoryLoader.Result) -> Void) {
        let end = currentDate()
        store.retrieve(from: end.addingTimeInterval(-range.duration), to: end) { result in
            switch result {
            case .success(let readings):
                completion(.success(PlantHistoryDownsampler.downsample(readings, bucket: range.bucket)))
            case .failure:
                completion(.failure(Error.retrieval))
            }
        }
    }

    public func subscribe(update: @escaping () -> Void) {
        store.subscribe(update: update)
    }
}
