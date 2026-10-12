import Foundation

/// Cleans a chat reply and spots the ones that can't be shown. Deterministic.
enum PlantChatReplyGuard {
    static let maximumSentences = 3

    private static let blocklist: Set<String> = [
        "prick", "idiot", "stupid", "dumb", "moron", "jerk", "fool", "loser",
        "shit", "shitty", "crap", "fuck", "fucking", "damn", "dammit", "bastard", "bitch", "asshole", "ass"
    ]

    /// Without stage directions (`*…*`, `(…)`) and with at most the first three sentences.
    static func clean(_ text: String) -> String {
        let spoken = PlantSpeechText.removingStageDirections(text)
        var sentences: [String] = []
        spoken.enumerateSubstrings(in: spoken.startIndex..., options: .bySentences) { sentence, _, _, stop in
            if let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), sentence.isEmpty == false {
                sentences.append(sentence)
            }
            if sentences.count == maximumSentences { stop = true }
        }
        return sentences.joined(separator: " ")
    }

    /// True when a cleaned reply is empty or contains a word from the blocklist.
    static func isRejected(_ cleaned: String) -> Bool {
        guard cleaned.isEmpty == false else { return true }
        let words = cleaned.lowercased().components(separatedBy: CharacterSet.letters.inverted)
        return words.contains(where: blocklist.contains)
    }
}
