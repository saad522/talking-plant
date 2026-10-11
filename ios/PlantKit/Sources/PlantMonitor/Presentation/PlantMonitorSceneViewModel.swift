import Foundation
import PlantShared

public enum PlantMonitorScene: Equatable, Sendable {
    case day
    case thirsty
    case night
}

public final class PlantMonitorSceneViewModel {
    /// Below this light level (lux) the scene is night.
    public static let nightLux = 10

    public let reading: PlantReading?
    public let scene: PlantMonitorScene
    /// The three chips to show, in order.
    public let sensors: [PlantSensorKind]
    /// The chips that get the warning style. They follow the mood, not the scene.
    public let warnings: [PlantSensorKind]

    public init(reading: PlantReading?, mood: PlantMood?) {
        self.reading = reading
        let isDark = (reading?.lux.map { $0 < Self.nightLux } ?? false) || mood == .offline
        let isThirsty = mood == .thirsty || mood == .veryThirsty
        self.scene = isDark ? .night : (isThirsty ? .thirsty : .day)
        self.sensors = mood == .dryAir ? [.moisture, .light, .humidity] : [.moisture, .light, .temperature]
        self.warnings = isThirsty ? [.moisture] : (mood == .dryAir ? [.humidity] : [])
    }
}
