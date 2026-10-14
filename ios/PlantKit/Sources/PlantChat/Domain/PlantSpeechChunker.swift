/// Splits a line into chunks so the first one can play while the rest is generated.
public enum PlantSpeechChunker {
    public static let defaultMaxWords = 12
    /// Peak memory grows with chunk length, so a chunk is also capped in characters (spaces included).
    /// A single word longer than this stays whole.
    public static let defaultMaxCharacters = 45
    /// Chunks shorter than this (in characters) are joined to a neighbour: Kokoro sounds weak on very short input.
    public static let minimumLength = 20

    private static let sentenceEnds: Set<Character> = [".", "!", "?", "…"]
    private static let clauseEnds: Set<Character> = [",", ";", ":", "—", "–"]
    private static let dashes: Set<String> = ["-", "—", "–"]
    /// A split never leaves one of these at the end of a chunk.
    private static let functionWords: Set<String> = [
        "a", "an", "the", "to", "of", "in", "on", "at", "by", "for", "and", "or", "but", "so", "as", "if",
        "is", "it", "my", "your", "our", "its", "with", "from", "i", "i'm", "that", "than", "into",
    ]
    private static let abbreviations: Set<String> = [
        "mr.", "mrs.", "ms.", "dr.", "prof.", "st.", "vs.", "e.g.", "i.e.",
    ]

    public static func chunks(_ text: String, maxWords: Int = defaultMaxWords, maxCharacters: Int = defaultMaxCharacters) -> [String] {
        let limit = Limit(words: max(maxWords, 1), characters: max(maxCharacters, 1))
        let parts = sentences(in: text).flatMap { split($0, limit: limit) }
        return merge(parts, limit: limit).map { $0.joined(separator: " ") }
    }

    private struct Limit {
        let words: Int
        let characters: Int

        func allows(_ words: some Collection<Substring>) -> Bool {
            words.count <= self.words && PlantSpeechChunker.length(of: Array(words)) <= characters
        }
    }

    /// Joins a short chunk to the next one, or to the previous one if it is last, never going over the limit.
    private static func merge(_ parts: [[Substring]], limit: Limit) -> [[Substring]] {
        var merged: [[Substring]] = []
        var pending: [Substring] = []
        for part in parts {
            if pending.isEmpty {
                pending = part
            } else if limit.allows(pending + part) {
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
            if let last = merged.last, limit.allows(last + pending) {
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

    /// Cuts a sentence that is over the limit. In the longest prefix that fits, it cuts after the last
    /// comma, semicolon, colon or dash that leaves at least `minimumLength` characters. Otherwise it
    /// cuts at a word boundary, moving back so the chunk doesn't end on "a", "the", "to" and so on.
    private static func split(_ sentence: [Substring], limit: Limit) -> [[Substring]] {
        var parts: [[Substring]] = []
        var rest = sentence[...]
        while !limit.allows(rest) {
            var fitting = 1
            while fitting < rest.count, limit.allows(rest.prefix(fitting + 1)) { fitting += 1 }
            let window = Array(rest.prefix(fitting))
            let clauseCut = window.indices.last { index in
                endsClause(window[index]) && length(of: Array(window[...index])) >= minimumLength
            }.map { $0 + 1 }
            parts.append(Array(rest.prefix(clauseCut ?? wordCut(window))))
            rest = rest.dropFirst(parts[parts.count - 1].count)
        }
        if !rest.isEmpty { parts.append(Array(rest)) }
        return parts
    }

    private static func endsClause(_ word: Substring) -> Bool {
        dashes.contains(String(word)) || (word.last.map(clauseEnds.contains) ?? false)
    }

    private static func wordCut(_ window: [Substring]) -> Int {
        var cut = window.count
        while cut > 1, functionWords.contains(window[cut - 1].lowercased()) { cut -= 1 }
        return cut
    }
}
