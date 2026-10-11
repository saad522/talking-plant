import Foundation

public enum PlantHistoryRange: Hashable, CaseIterable, Sendable {
    case day
    case week

    /// How far back the range reaches from now.
    public var duration: TimeInterval {
        switch self {
        case .day: 24 * 3_600
        case .week: 7 * 24 * 3_600
        }
    }

    /// Width of one averaged chart point.
    public var bucket: TimeInterval {
        switch self {
        case .day: 10 * 60
        case .week: 3_600
        }
    }
}
