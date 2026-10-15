import PlantShared

@MainActor
public final class PlantSoundEffectSettings {
    static let key = "plant.chat.soundEffects.enabled"

    private let defaults: DefaultsClient

    public init(defaults: DefaultsClient) {
        self.defaults = defaults
    }

    /// Whether Sprout's reward sounds play. On when nothing is saved.
    public var isEnabled: Bool {
        defaults.retrieveBool(forKey: Self.key) ?? true
    }

    public func save(isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Self.key)
    }
}
