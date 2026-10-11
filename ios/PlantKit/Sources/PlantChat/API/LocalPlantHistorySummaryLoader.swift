import Foundation
import PlantShared

@MainActor
public final class LocalPlantHistorySummaryLoader: PlantHistorySummaryLoader {
    private let store: PlantReadingStore
    private let currentDate: () -> Date

    public enum Error: Swift.Error, Equatable {
        case retrieval
    }

    /// - Parameter currentDate: "Now" for the window. Pass the simulated clock in simulated mode.
    public init(store: PlantReadingStore, currentDate: @escaping () -> Date = Date.init) {
        self.store = store
        self.currentDate = currentDate
    }

    public func load(_ period: PlantHistorySummary.Period, completion: @escaping (PlantHistorySummaryLoader.Result) -> Void) {
        let end = currentDate()
        store.retrieve(from: end.addingTimeInterval(-Self.duration(of: period)), to: end) { result in
            switch result {
            case .success(let readings):
                completion(.success(Self.summary(of: readings, period: period)))
            case .failure:
                completion(.failure(Error.retrieval))
            }
        }
    }

    private static func duration(of period: PlantHistorySummary.Period) -> TimeInterval {
        switch period {
        case .day: 24 * 60 * 60
        case .week: 7 * 24 * 60 * 60
        }
    }

    private static func summary(of readings: [PlantReading], period: PlantHistorySummary.Period) -> PlantHistorySummary {
        PlantHistorySummary(
            period: period,
            readingCount: readings.count,
            moisture: statistics(readings.compactMap(\.moisture)),
            lux: statistics(readings.compactMap { $0.lux.map(Double.init) }),
            temperature: statistics(readings.compactMap(\.temperature)),
            humidity: statistics(readings.compactMap(\.humidity))
        )
    }

    private static func statistics(_ values: [Double]) -> PlantHistorySummary.Statistics? {
        guard let minimum = values.min(), let maximum = values.max() else { return nil }
        return PlantHistorySummary.Statistics(
            minimum: minimum,
            average: values.reduce(0, +) / Double(values.count),
            maximum: maximum
        )
    }
}
