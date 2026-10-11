import PlantShared

@MainActor
public final class PlantSpokenReplySettings {
    static let key = "plant.chat.spokenReplies.enabled"

    private let defaults: DefaultsClient

    public init(defaults: DefaultsClient) {
        self.defaults = defaults
    }

    /// Whether replies to spoken turns are spoken. On when nothing is saved.
    public var isEnabled: Bool {
        defaults.retrieveBool(forKey: Self.key) ?? true
    }

    public func save(isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Self.key)
    }
}
