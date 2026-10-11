import Foundation
import PlantShared

public enum PlantSensorKind: Equatable, CaseIterable {
    case moisture
    case light
    case temperature
    case humidity
}

public final class PlantSensorCardViewModel {
    public let title: String
    public let value: String

    public init(kind: PlantSensorKind, reading: PlantReading) {
        self.title = switch kind {
        case .moisture: String.localised(key: "plant.monitor.moisture.title")
        case .light: String.localised(key: "plant.monitor.light.title")
        case .temperature: String.localised(key: "plant.monitor.temperature.title")
        case .humidity: String.localised(key: "plant.monitor.humidity.title")
        }
        self.value = switch kind {
        case .moisture: PlantReadingFormatter.percent(reading.moisture)
        case .light: PlantReadingFormatter.lux(reading.lux)
        case .temperature: PlantReadingFormatter.temperature(reading.temperature)
        case .humidity: PlantReadingFormatter.percent(reading.humidity)
        }
    }
}
