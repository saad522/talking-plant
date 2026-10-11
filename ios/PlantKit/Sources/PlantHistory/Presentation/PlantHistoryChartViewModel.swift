import Foundation
import PlantShared

public enum PlantHistoryMetric: Hashable, CaseIterable, Sendable {
    case moisture
    case light
    case temperature
    case humidity
}

public struct PlantHistoryChartPoint: Equatable, Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public final class PlantHistoryChartViewModel {
    public let title: String
    /// The most recent value, formatted, or a placeholder when there is none.
    public let latestValue: String
    public let points: [PlantHistoryChartPoint]

    public init(metric: PlantHistoryMetric, samples: [PlantHistorySample]) {
        let value: (PlantHistorySample) -> Double? = switch metric {
        case .moisture: \.moisture
        case .light: \.lux
        case .temperature: \.temperature
        case .humidity: \.humidity
        }
        let points = samples.compactMap { sample in
            value(sample).map { PlantHistoryChartPoint(date: sample.date, value: $0) }
        }
        let latest = points.last?.value

        self.points = points
        self.title = switch metric {
        case .moisture: String.localised(key: "plant.history.moisture.title")
        case .light: String.localised(key: "plant.history.light.title")
        case .temperature: String.localised(key: "plant.history.temperature.title")
        case .humidity: String.localised(key: "plant.history.humidity.title")
        }
        self.latestValue = switch metric {
        case .moisture, .humidity: PlantReadingFormatter.percent(latest)
        case .light: PlantReadingFormatter.lux(latest.map { Int($0.rounded()) })
        case .temperature: PlantReadingFormatter.temperature(latest)
        }
    }
}
