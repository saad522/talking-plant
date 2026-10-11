import Foundation

@MainActor
public protocol PlantChatLoader {
    typealias Result = Swift.Result<String, Error>

    var isAvailable: Bool { get }
    func send(_ text: String, facts: PlantVoiceFacts, completion: @escaping (Result) -> Void)
    /// Forgets the conversation so far.
    func reset()
}
