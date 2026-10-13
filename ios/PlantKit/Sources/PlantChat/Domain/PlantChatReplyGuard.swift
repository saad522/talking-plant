import Foundation
import PlantShared

/// Cleans a chat reply and spots the ones that can't be shown. Deterministic.
enum PlantChatReplyGuard {
    static let maximumSentences = 3
    /// Replies opening with the same words count as repeats.
    static let openingWords = 6

    private static let blocklist: Set<String> = [
        "prick", "idiot", "stupid", "dumb", "moron", "jerk", "fool", "loser",
        "shit", "shitty", "crap", "fuck", "fucking", "damn", "dammit", "bastard", "bitch", "asshole", "ass"
    ]

    /// Claims that the soil needs water.
    private static let thirstClaims = [
        "thirsty", "parched", "need water", "need some water", "need a drink", "dry soil", "soil is dry"
    ]
    /// Claims that it doesn't. Removed before looking for `thirstClaims`, so "not thirsty" isn't a thirst claim.
    private static let noThirstClaims = [
        "not thirsty", "don't need water", "do not need water", "don't need any water", "don't need a drink"
    ]
    /// The plant taking the person's role.
    private static let roleSwaps = [
        "i'll water you", "i will water you", "let me water you",
        "i'll feed you", "i will feed you", "let me feed you",
        "i'll help you", "i will help you", "let me help you"
    ]
    /// Openings that echo the person instead of answering.
    private static let echoOpenings = ["you're asking", "you are asking", "you asked", "you did", "you said"]

    /// Without markdown, line breaks and stage directions (`*…*`, `(…)`), and with at most the first three sentences.
    static func clean(_ text: String) -> String {
        sentences(in: PlantSpeechText.removingStageDirections(PlantSpeechText.removingMarkdown(text)))
            .prefix(maximumSentences)
            .joined(separator: " ")
    }

    /// The first sentence of a cleaned reply, or "" when there is none.
    static func firstSentence(of cleaned: String) -> String {
        sentences(in: cleaned).first ?? ""
    }

    /// True when a cleaned reply is empty or contains a word from the blocklist.
    static func isRejected(_ cleaned: String) -> Bool {
        guard cleaned.isEmpty == false else { return true }
        let words = cleaned.lowercased().components(separatedBy: CharacterSet.letters.inverted)
        return words.contains(where: blocklist.contains)
    }

    /// True when a reply says the opposite of the mood about water:
    /// thirsty while happy or drowning, or not needing water while thirsty.
    static func contradicts(_ reply: String, mood: PlantMood) -> Bool {
        let text = phrases(reply)
        switch mood {
        case .happy, .drowning:
            let affirmative = noThirstClaims.reduce(text) { $0.replacingOccurrences(of: " \($1) ", with: " ") }
            return mentions(affirmative, anyOf: thirstClaims)
        case .thirsty, .veryThirsty:
            return mentions(text, anyOf: noThirstClaims)
        case .tooDark, .tooHot, .tooCold, .dryAir, .offline:
            return false
        }
    }

    /// True when a greeting fits the mood: it doesn't contradict it, and a problem mood mentions its need.
    static func greetingFits(_ line: String, mood: PlantMood) -> Bool {
        let needs = needs(of: mood)
        return contradicts(line, mood: mood) == false && (needs.isEmpty || mentions(phrases(line), anyOf: needs))
    }

    /// True when a reply offers to look after the person ("I'll water you") or opens by echoing them ("You're asking…").
    static func confusesRoles(_ reply: String) -> Bool {
        let text = phrases(reply)
        return mentions(text, anyOf: roleSwaps) || echoOpenings.contains { text.hasPrefix(" \($0) ") }
    }

    /// True when a reply matches one of the recent replies, ignoring case, punctuation and numbers,
    /// or opens with the same six words.
    static func repeats(_ reply: String, anyOf recentReplies: [String]) -> Bool {
        let normalized = normalized(reply)
        let opening = opening(of: normalized)
        return recentReplies.map(Self.normalized).contains { recent in
            recent == normalized || (opening != nil && self.opening(of: recent) == opening)
        }
    }

    // MARK: - Private helpers

    private static func sentences(in text: String) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), sentence.isEmpty == false {
                sentences.append(sentence)
            }
        }
        return sentences
    }

    /// The words the mood is about, one of which a greeting must mention. Empty when nothing is needed.
    private static func needs(of mood: PlantMood) -> [String] {
        switch mood {
        case .happy: []
        case .thirsty, .veryThirsty: ["water", "drink", "thirsty", "parched", "dry"]
        case .drowning: ["wet", "soggy", "drowning", "too much water", "dry out"]
        case .tooDark: ["dark", "light", "sun", "sunlight", "sunshine"]
        case .tooHot: ["hot", "warm", "heat", "cool"]
        case .tooCold: ["cold", "chilly", "brr", "freezing", "warm", "warmer"]
        case .dryAir: ["air", "humid", "humidity", "mist", "dry"]
        case .offline: ["sensor", "offline", "connection"]
        }
    }

    /// Lowercased words separated and surrounded by single spaces, so phrases only match whole words.
    private static func phrases(_ text: String) -> String {
        let words = text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.letters.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { $0.isEmpty == false }
        return " " + words.joined(separator: " ") + " "
    }

    private static func mentions(_ phrases: String, anyOf keywords: [String]) -> Bool {
        keywords.contains { phrases.contains(" \($0) ") }
    }

    /// Lowercased, trimmed, without punctuation and with every number as "#",
    /// so "I'm at 24%!" and "im at 30" count as the same reply.
    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: .punctuationCharacters).joined()
            .replacingOccurrences(of: #"\d+"#, with: "#", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func opening(of normalized: String) -> [Substring]? {
        let words = normalized.split(separator: " ")
        return words.count >= openingWords ? Array(words.prefix(openingWords)) : nil
    }
}
