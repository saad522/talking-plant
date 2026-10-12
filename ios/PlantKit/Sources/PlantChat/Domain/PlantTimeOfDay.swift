public enum PlantTimeOfDay: String, Equatable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    /// - Parameter hour: 0–23 on the phone's clock.
    public init(hour: Int) {
        switch hour {
        case 5..<12: self = .morning
        case 12..<17: self = .afternoon
        case 17..<21: self = .evening
        default: self = .night
        }
    }
}
