import Foundation

@MainActor
public protocol PlantHistorySummaryLoader {
    typealias Result = Swift.Result<PlantHistorySummary, Error>

    func load(_ period: PlantHistorySummary.Period, completion: @escaping (Result) -> Void)
}
