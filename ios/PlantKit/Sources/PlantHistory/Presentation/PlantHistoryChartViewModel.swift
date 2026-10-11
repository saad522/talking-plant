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

public enum PlantHistoryYDomain: Equatable, Sendable {
    case fixed(ClosedRange<Double>)
    case automatic(includesZero: Bool)
}

public struct PlantHistoryAxisStride: Equatable, Sendable {
    public let component: Calendar.Component
    public let count: Int
}

public final class PlantHistoryChartViewModel {
    public let title: String
    /// The most recent value, formatted, or a placeholder when there is none.
    public let latestValue: String
    public let points: [PlantHistoryChartPoint]
    /// The whole range, ending one bucket after the latest sample, so every metric's chart
    /// shows the same window. `nil` without samples.
    public let xDomain: ClosedRange<Date>?
    public let xAxisStride: PlantHistoryAxisStride
    public let yDomain: PlantHistoryYDomain

    private let xAxisFormat: Date.VerbatimFormatStyle

    public init(
        metric: PlantHistoryMetric,
        samples: [PlantHistorySample],
        range: PlantHistoryRange,
        calendar: Calendar = .current
    ) {
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
        self.xDomain = samples.last.map { last in
            let end = last.date.addingTimeInterval(range.bucket)
            return end.addingTimeInterval(-range.duration)...end
        }
        self.yDomain = switch metric {
        case .moisture: .fixed(0...100)
        case .light: .automatic(includesZero: true)
        case .temperature, .humidity: .automatic(includesZero: false)
        }
        self.xAxisStride = switch range {
        case .day: PlantHistoryAxisStride(component: .hour, count: 6)
        case .week: PlantHistoryAxisStride(component: .day, count: 1)
        }
        let format: Date.FormatString = switch range {
        case .day: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))"
        case .week: "\(weekday: .abbreviated)"
        }
        self.xAxisFormat = Date.VerbatimFormatStyle(
            format: format,
            locale: PlantReadingFormatter.locale,
            timeZone: calendar.timeZone,
            calendar: calendar
        )
    }

    /// Hours ("08") for 24 hours, short weekdays ("Mon") for 7 days.
    public func xAxisLabel(for date: Date) -> String {
        date.formatted(xAxisFormat)
    }

    public func yAxisLabel(for value: Double) -> String {
        PlantReadingFormatter.number(value)
    }
}
