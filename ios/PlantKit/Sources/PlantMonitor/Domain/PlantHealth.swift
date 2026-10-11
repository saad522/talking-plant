import PlantShared

/// Declared in priority order: the first issue present decides the mood.
public enum PlantHealthIssue: Equatable, Sendable, CaseIterable {
    case offline
    case drowning
    case veryThirsty
    case tooHot
    case tooCold
    case thirsty
    case tooDark
    case dryAir

    public var mood: PlantMood {
        switch self {
        case .offline: .offline
        case .drowning: .drowning
        case .veryThirsty: .veryThirsty
        case .tooHot: .tooHot
        case .tooCold: .tooCold
        case .thirsty: .thirsty
        case .tooDark: .tooDark
        case .dryAir: .dryAir
        }
    }

    /// Points taken off the score. Offline takes none: the score is the last known condition.
    public var penalty: Int {
        switch self {
        case .offline: 0
        case .drowning: 60
        case .veryThirsty: 60
        case .tooHot: 40
        case .tooCold: 40
        case .thirsty: 30
        case .tooDark: 25
        case .dryAir: 15
        }
    }
}

public struct PlantHealth: Equatable, Sendable {
    /// 0...100.
    public let score: Int
    /// Sorted by priority, most important first.
    public let issues: [PlantHealthIssue]

    public var mood: PlantMood {
        issues.first?.mood ?? .happy
    }

    public init(score: Int, issues: [PlantHealthIssue]) {
        self.score = score
        self.issues = issues
    }
}
