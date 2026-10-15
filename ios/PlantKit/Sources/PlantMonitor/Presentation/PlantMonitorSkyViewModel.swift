import Foundation

/// The sun or moon and where it sits on its arc. The scene picks the body, the clock picks the place.
public final class PlantMonitorSkyViewModel {
    public enum Body: Equatable, Sendable {
        case sun
        case moon
    }

    private static let minutesPerDay = 1_440.0
    private static let arcMinutes = 720.0

    public let body: Body
    /// 0 at the start of the arc, 1 at its end. The sun runs 06:00 to 18:00, the moon 18:00 to 06:00.
    /// Outside its own hours a body waits at the nearest end.
    public let progress: Double

    public init(scene: PlantMonitorScene, date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
        switch scene {
        case .night:
            body = .moon
            progress = Self.clamp(((minutes - 1_080 + Self.minutesPerDay).truncatingRemainder(dividingBy: Self.minutesPerDay)) / Self.arcMinutes)
        case .day, .thirsty:
            body = .sun
            progress = Self.clamp((minutes - 360) / Self.arcMinutes)
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
