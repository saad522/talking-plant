import Foundation
import PlantShared

@MainActor
public final class LocalPlantHealthLoader: PlantHealthLoader {
    public typealias Schedule = @MainActor (_ interval: TimeInterval, _ tick: @escaping @MainActor @Sendable () -> Bool) -> Void

    private let store: PlantReadingStore
    private let profile: PlantProfile
    private let currentDate: () -> Date
    private let recheckInterval: TimeInterval
    private let schedule: Schedule

    public enum Error: Swift.Error, Equatable {
        case retrieval
    }

    /// - Parameters:
    ///   - currentDate: "Now" for the evaluation. Pass the simulated clock in simulated mode.
    ///   - recheckInterval: How often to ask for a new evaluation without a new reading, so offline can show.
    ///   - schedule: Calls `tick` every interval until it returns `false`.
    public init(
        store: PlantReadingStore,
        profile: PlantProfile,
        currentDate: @escaping () -> Date = Date.init,
        recheckInterval: TimeInterval,
        schedule: @escaping Schedule
    ) {
        self.store = store
        self.profile = profile
        self.currentDate = currentDate
        self.recheckInterval = recheckInterval
        self.schedule = schedule
    }

    public func load(completion: @escaping (PlantHealthLoader.Result) -> Void) {
        let now = currentDate()
        let profile = profile
        store.retrieve(from: now.addingTimeInterval(-profile.historyWindow), to: now) { result in
            switch result {
            case .success(let readings):
                completion(.success(PlantHealthEvaluator.evaluate(readings: readings, now: now, profile: profile)))
            case .failure:
                completion(.failure(Error.retrieval))
            }
        }
    }

    public func subscribe(update: @escaping () -> Void) {
        store.subscribe(update: update)
        nonisolated(unsafe) let recheck = update
        schedule(recheckInterval) {
            recheck()
            return true
        }
    }
}
