/// Splits a line into chunks so the first one can play while the rest is generated.
public enum PlantSpeechChunker {
    public static let defaultMaxWords = 20
    /// Chunks shorter than this (in characters) are joined to a neighbour: Kokoro sounds weak on very short input.
    public static let minimumLength = 20

    private static let sentenceEnds: Set<Character> = [".", "!", "?", "…"]
    private static let clauseEnds: Set<Character> = [",", ";", ":"]
    private static let abbreviations: Set<String> = [
        "mr.", "mrs.", "ms.", "dr.", "prof.", "st.", "vs.", "e.g.", "i.e.",
    ]

    public static func chunks(_ text: String, maxWords: Int = defaultMaxWords) -> [String] {
        let maxWords = max(maxWords, 1)
        let parts = sentences(in: text).flatMap { split($0, maxWords: maxWords) }
        return merge(parts, maxWords: maxWords).map { $0.joined(separator: " ") }
    }

    /// Joins a short chunk to the next one, or to the previous one if it is last, never going over `maxWords`.
    private static func merge(_ parts: [[Substring]], maxWords: Int) -> [[Substring]] {
        var merged: [[Substring]] = []
        var pending: [Substring] = []
        for part in parts {
            if pending.isEmpty {
                pending = part
            } else if pending.count + part.count <= maxWords {
                pending += part
            } else {
                merged.append(pending)
                pending = part
            }
            if length(of: pending) >= minimumLength {
                merged.append(pending)
                pending = []
            }
        }
        if !pending.isEmpty {
            if let last = merged.last, last.count + pending.count <= maxWords {
                merged[merged.count - 1] = last + pending
            } else {
                merged.append(pending)
            }
        }
        return merged
    }

    private static func length(of words: [Substring]) -> Int {
        words.reduce(0) { $0 + $1.count } + max(words.count - 1, 0)
    }

    private static func sentences(in text: String) -> [[Substring]] {
        var sentences: [[Substring]] = []
        var current: [Substring] = []
        for word in text.split(whereSeparator: \.isWhitespace) {
            current.append(word)
            if endsSentence(word) {
                sentences.append(current)
                current = []
            }
        }
        if !current.isEmpty { sentences.append(current) }
        return sentences
    }

    private static func endsSentence(_ word: Substring) -> Bool {
        guard let last = word.last, sentenceEnds.contains(last) else { return false }
        return !abbreviations.contains(word.lowercased())
    }

    private static func split(_ sentence: [Substring], maxWords: Int) -> [[Substring]] {
        var parts: [[Substring]] = []
        var rest = sentence[...]
        while rest.count > maxWords {
            let window = rest.prefix(maxWords)
            let cut = window.lastIndex { word in word.last.map(clauseEnds.contains) ?? false }
                .map { $0 + 1 } ?? window.endIndex
            parts.append(Array(rest[rest.startIndex..<cut]))
            rest = rest[cut...]
        }
        if !rest.isEmpty { parts.append(Array(rest)) }
        return parts
    }
}
