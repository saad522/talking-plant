import Foundation

public enum PlantIntroParticleStyle: Equatable, Sendable {
    /// Warm yellow lights, at night.
    case fireflies
    /// Pale green sparkles, by day.
    case pollen
}

public enum PlantIntroPeriod: Equatable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    public var particleStyle: PlantIntroParticleStyle {
        switch self {
        case .morning, .afternoon: .pollen
        case .evening, .night: .fireflies
        }
    }
}

public enum PlantIntroGreeting {
    public static var title: String { .localised(key: "plant.intro.title") }

    /// 5-11 morning, 12-17 afternoon, 18-22 evening, 23-4 night. Hours outside 0-23 wrap around.
    public static func period(for hour: Int) -> PlantIntroPeriod {
        switch ((hour % 24) + 24) % 24 {
        case 5...11: .morning
        case 12...17: .afternoon
        case 18...22: .evening
        default: .night
        }
    }

    public static func greeting(for hour: Int) -> String {
        switch period(for: hour) {
        case .morning: .localised(key: "plant.intro.greeting.morning")
        case .afternoon: .localised(key: "plant.intro.greeting.afternoon")
        case .evening: .localised(key: "plant.intro.greeting.evening")
        case .night: .localised(key: "plant.intro.greeting.night")
        }
    }
}
