import Foundation

/// The on-device language model. Implemented with Foundation Models in the app.
@MainActor
public protocol PlantLanguageModelClient {
    var isAvailable: Bool { get }
    func makeSession(instructions: String, canReadHistory: Bool) -> PlantLanguageModelSession
}

@MainActor
public protocol PlantLanguageModelSession: AnyObject {
    typealias Result = Swift.Result<String, Error>

    /// Remembers earlier turns of the same session.
    func respond(to prompt: String, completion: @escaping (Result) -> Void)
}

public enum PlantLanguageModelError: Error, Equatable {
    case contextTooLong
    case generation
}
