import Foundation

/// Splits a line into sentence chunks so the first one can play while the rest is generated.
public enum KokoroSpikeSentences {
    /// Chunks shorter than this are joined to the next one: Kokoro sounds weak on very short input.
    public static let minimumLength = 20

    public static func chunks(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        var previous: Character?
        for character in text {
            if character.isWhitespace, let previous, ".!?".contains(previous) {
                sentences.append(current)
                current = ""
            } else {
                current.append(character)
            }
            previous = character
        }
        sentences.append(current)

        var chunks: [String] = []
        var pending = ""
        for sentence in sentences.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !sentence.isEmpty {
            pending = pending.isEmpty ? sentence : pending + " " + sentence
            if pending.count >= minimumLength {
                chunks.append(pending)
                pending = ""
            }
        }
        if !pending.isEmpty {
            if let last = chunks.popLast() {
                chunks.append(last + " " + pending)
            } else {
                chunks.append(pending)
            }
        }
        return chunks
    }
}
