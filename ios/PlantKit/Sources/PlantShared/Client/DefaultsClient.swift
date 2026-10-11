import Foundation

/// Small key-value storage. Add value types here when a feature needs them.
@MainActor
public protocol DefaultsClient {
    func set(_ value: Double, forKey key: String)
    func retrieve(forKey key: String) -> Double?
}
