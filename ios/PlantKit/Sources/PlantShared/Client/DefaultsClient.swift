import Foundation

/// Small key-value storage. Add value types here when a feature needs them.
@MainActor
public protocol DefaultsClient {
    func set(_ value: Double, forKey key: String)
    func retrieve(forKey key: String) -> Double?
    func set(_ value: String, forKey key: String)
    func retrieveString(forKey key: String) -> String?
    func set(_ value: Bool, forKey key: String)
    func retrieveBool(forKey key: String) -> Bool?
}
