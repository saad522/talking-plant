import PlantShared

@MainActor
public final class PlantPersonalitySettings {
    static let key = "plant.chat.personality"

    private let defaults: DefaultsClient

    public init(defaults: DefaultsClient) {
        self.defaults = defaults
    }

    /// The saved personality, or `.cheerful` when nothing valid or available is saved.
    public func load() -> PlantPersonality {
        let saved = defaults.retrieveString(forKey: Self.key).flatMap(PlantPersonality.init(rawValue:))
        return saved.flatMap { PlantPersonality.available.contains($0) ? $0 : nil } ?? .cheerful
    }

    public func save(_ personality: PlantPersonality) {
        defaults.set(personality.rawValue, forKey: Self.key)
    }
}
