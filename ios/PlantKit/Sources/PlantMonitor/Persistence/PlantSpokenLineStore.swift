import Foundation
import PlantShared

/// Remembers the last mood Sprout spoke on home and on which day, so a relaunch stays quiet.
@MainActor
public final class PlantSpokenLineStore {
    private let defaults: DefaultsClient
    private let moodKey = "plant.monitor.spoken.mood"
    private let dayKey = "plant.monitor.spoken.day"

    public init(defaults: DefaultsClient) {
        self.defaults = defaults
    }

    public var mood: PlantMood? {
        defaults.retrieveString(forKey: moodKey).flatMap(Self.mood(named:))
    }

    public var day: String? {
        defaults.retrieveString(forKey: dayKey)
    }

    public func save(mood: PlantMood, day: String) {
        defaults.set(Self.name(of: mood), forKey: moodKey)
        defaults.set(day, forKey: dayKey)
    }

    /// The phone's local calendar day, as it is stored.
    public static func day(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func name(of mood: PlantMood) -> String {
        String(describing: mood)
    }

    private static func mood(named name: String) -> PlantMood? {
        PlantMood.allCases.first { self.name(of: $0) == name }
    }
}
