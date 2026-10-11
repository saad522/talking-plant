import Foundation

@MainActor
public final class UserDefaultsClient: DefaultsClient {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func set(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func retrieve(forKey key: String) -> Double? {
        defaults.object(forKey: key) as? Double
    }

    public func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func retrieveString(forKey key: String) -> String? {
        defaults.object(forKey: key) as? String
    }

    public func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func retrieveBool(forKey key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }
}
