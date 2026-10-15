import Foundation
import PlantShared

public enum PlantMonitorScene: String, Equatable, Sendable {
    case day
    case thirsty
    case night
}

public final class PlantMonitorSceneViewModel {
    /// Below this light level (lux) the scene is night.
    public static let nightLux = 10

    /// The mood the face is drawn with while the plant sleeps. `PlantFace` draws it as asleep.
    public static let sleepingFaceMood: PlantMood = .tooDark

    public let reading: PlantReading?
    public let mood: PlantMood?
    public let connection: PlantConnection?
    public let scene: PlantMonitorScene
    /// A happy plant at night sleeps. Any other mood stays awake to show itself.
    public let isSleeping: Bool
    /// Water leads whenever the plant is thirsty, in every scene.
    public let isWaterPrimary: Bool
    /// The three chips to show, in order.
    public let sensors: [PlantSensorKind]
    /// The chips that get the warning style. They follow the mood, not the scene.
    public let warnings: [PlantSensorKind]

    public init(reading: PlantReading?, mood: PlantMood?, connection: PlantConnection? = nil) {
        self.reading = reading
        self.mood = mood
        self.connection = connection
        let isDark = (reading?.lux.map { $0 < Self.nightLux } ?? false) || mood == .offline
        let isThirsty = mood == .thirsty || mood == .veryThirsty
        self.isWaterPrimary = isThirsty
        self.scene = isDark ? .night : (isThirsty ? .thirsty : .day)
        self.isSleeping = self.scene == .night && mood == .happy
        self.sensors = mood == .dryAir ? [.moisture, .light, .humidity] : [.moisture, .light, .temperature]
        self.warnings = isThirsty ? [.moisture] : (mood == .dryAir ? [.humidity] : [])
    }

    /// The mood to draw the face with, or nil before a mood loads.
    public var faceMood: PlantMood? {
        isSleeping ? Self.sleepingFaceMood : mood
    }

    /// The speech bubble line, or nil before a mood loads.
    public var speech: String? {
        guard let mood else { return nil }
        return isSleeping
            ? String.localised(key: "plant.monitor.sleeping.speech")
            : PlantMoodViewModel(mood: mood).speech
    }

    public func header(name: String, room: String) -> PlantMonitorHeaderViewModel {
        PlantMonitorHeaderViewModel(name: name, room: room, mood: mood, isSleeping: isSleeping, connection: connection)
    }
}
