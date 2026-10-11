import PlantShared

@MainActor
public final class PlantPersonalitySettings {
    static let key = "plant.chat.personality"

    private let defaults: DefaultsClient

    public init(defaults: DefaultsClient) {
        self.defaults = defaults
    }

    /// The saved personality, or `.cheerful` when nothing valid is saved.
    public func load() -> PlantPersonality {
        defaults.retrieveString(forKey: Self.key).flatMap(PlantPersonality.init(rawValue:)) ?? .cheerful
    }

    public func save(_ personality: PlantPersonality) {
        defaults.set(personality.rawValue, forKey: Self.key)
    }
}
