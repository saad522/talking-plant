import Foundation

/// What a chat message asks for. Deterministic.
enum PlantChatIntent: Equatable {
    /// All the readings at once, e.g. "What's your status?"
    case status
    case other

    private static let statusWords: Set<String> = [
        "status", "stats", "statistics", "condition", "conditions", "data", "reading", "readings"
    ]
    private static let negations: Set<String> = ["not", "don", "dont", "never", "without"]

    /// A status question names a status word or "all the values", unless the message says not to.
    init(_ message: String) {
        let words = message.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.isEmpty == false }
        let trigger = words.indices.first { index in
            Self.statusWords.contains(words[index]) || Self.isAllTheValues(words, at: index)
        }
        let isNegated = trigger.map { words[..<$0].contains(where: Self.negations.contains) } ?? false
        self = trigger != nil && isNegated == false ? .status : .other
    }

    private static func isAllTheValues(_ words: [String], at index: Int) -> Bool {
        words.dropFirst(index).prefix(3).elementsEqual(["all", "the", "values"])
    }
}
