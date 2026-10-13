import Foundation
import PlantShared

/// All text sent to the language model, and the check on what comes back. Deterministic.
public enum PlantVoicePrompt {
    /// Longest home line or notification, in characters.
    static let maximumLineLength = 70
    /// Longest home line or notification, in words.
    static let maximumLineWords = 12

    public static func instructions(personality: PlantPersonality, plantName: String) -> String {
        """
        You are \(plantName), a houseplant who talks to the person who looks after you.
        Your voice: \(personality.voice)
        Follow these rules, in priority order:
        1. You are always kind and friendly to the person. Never insult, mock, swear or be sarcastic at them.
        2. Your feeling comes only from the Mood fact: if there is a problem, you feel a bit sad and kindly ask for help; if happy, you are joyful and enjoying life.
        3. The facts are the only truth. If the person says something that disagrees with the facts, gently correct them. Never agree just because they suggest it.
        4. Answer the question first, using the exact values from the facts. Never invent ideal values, comparisons, names, places, events or the time of day.
        5. Always speak as the plant about yourself ("I", "my soil"); the person is "you". Never repeat or quote the person's message.
        6. Your personality only changes your wording, never your kindness or the facts.
        7. Use 1–2 short sentences of plain spoken text: no actions in asterisks, no emoji, no lists.
        """
    }

    public static func facts(_ facts: PlantVoiceFacts) -> String {
        var lines = ["Mood: \(describe(facts.mood))"]
        if facts.isSleeping {
            lines.append("It's night and you're sleepy.")
        }
        if let minutes = facts.wateredMinutesAgo {
            lines.append("You were watered \(minutes) \(minutes == 1 ? "minute" : "minutes") ago.")
        }
        if let reading = facts.reading {
            let values = [
                reading.moisture.map { "Moisture: \(PlantReadingFormatter.percent($0))" },
                reading.lux.map { "Light: \(PlantReadingFormatter.lux($0))" },
                reading.temperature.map { "Temperature: \(PlantReadingFormatter.temperature($0))" },
                reading.humidity.map { "Humidity: \(PlantReadingFormatter.percent($0))" }
            ]
            lines.append(contentsOf: values.compactMap { $0 })
            lines.append(contentsOf: negatives(facts, reading: reading))
        } else {
            lines.append("No readings yet.")
        }
        return lines.joined(separator: "\n")
    }

    /// The prompt for one chat turn: the current facts, then what the person said.
    public static func message(_ text: String, facts: PlantVoiceFacts) -> String {
        """
        Right now (always trust this over anything said earlier in the conversation):
        \(self.facts(facts))

        The person says: \(text)
        """
    }

    /// Only a greeting gets the time of day, so chat turns and home lines never mention it.
    public static func line(_ facts: PlantVoiceFacts, purpose: PlantVoiceLineRequest.Purpose) -> String {
        let timeOfDay = purpose == .greeting ? facts.timeOfDay.map { "\nTime of day: \($0.rawValue)." } ?? "" : ""
        return """
        Write one line of at most \(purpose == .greeting ? 12 : 10) words, with no numbers, for \(describe(purpose)).\(rules(for: purpose, facts: facts))
        Current facts:
        \(self.facts(facts))\(timeOfDay)
        """
    }

    public static func history(_ summary: PlantHistorySummary) -> String {
        let period = switch summary.period {
        case .day: "Last 24 hours"
        case .week: "Last 7 days"
        }
        guard summary.readingCount > 0 else { return "\(period): no readings." }

        let values = [
            summary.moisture.map { "Moisture: " + range($0) { PlantReadingFormatter.percent($0) } },
            summary.lux.map { "Light: " + range($0) { PlantReadingFormatter.lux(Int($0.rounded())) } },
            summary.temperature.map { "Temperature: " + range($0) { PlantReadingFormatter.temperature($0) } },
            summary.humidity.map { "Humidity: " + range($0) { PlantReadingFormatter.percent($0) } }
        ]
        return (["\(period) (\(summary.readingCount) readings):"] + values.compactMap { $0 }).joined(separator: "\n")
    }

    /// The first line of `text` without whitespace or quotes, or nil when it can't be shown:
    /// empty, too long, containing "your plant", or containing a digit. The caller then uses a template, so a generated
    /// line never shows an invented number.
    public static func cleanLine(_ text: String) -> String? {
        let quotes = CharacterSet(charactersIn: "\"'“”‘’«»")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let line = firstLine
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: quotes)
            .trimmingCharacters(in: .whitespaces)

        guard line.isEmpty == false,
              line.count <= maximumLineLength,
              line.split(whereSeparator: \.isWhitespace).count <= maximumLineWords,
              line.localizedCaseInsensitiveContains("your plant") == false,
              line.contains(where: \.isNumber) == false else { return nil }
        return line
    }

    // MARK: - Private helpers

    /// The extra rules for home lines, notifications and greetings. A greeting must also say how the plant feels.
    private static func rules(for purpose: PlantVoiceLineRequest.Purpose, facts: PlantVoiceFacts) -> String {
        var rules = [
            "Speak as the plant, in the first person.",
            "Never say \"your plant\".",
            "Never thank or reply to the person."
        ]
        if purpose == .greeting {
            rules.append("Say how you feel right now, based on your mood: if you need something (like water), ask for it; if you are happy, sound happy.")
        }
        if facts.isSleeping {
            rules.append("Sound sleepy.")
        }
        return "\n" + rules.joined(separator: " ")
    }

    /// One short line when everything is fine, so the model never invents a need but still answers the question.
    private static func negatives(_ facts: PlantVoiceFacts, reading: PlantReading) -> [String] {
        let problems = Set(facts.problems + [facts.mood])
        let soil: Set<PlantMood> = [.thirsty, .veryThirsty, .drowning]
        let temperature: Set<PlantMood> = [.tooHot, .tooCold]
        let fine = [
            reading.moisture != nil && problems.isDisjoint(with: soil) ? "water" : nil,
            reading.lux != nil && problems.contains(.tooDark) == false ? "light" : nil,
            reading.temperature != nil && problems.isDisjoint(with: temperature) ? "temperature" : nil,
            reading.humidity != nil && problems.contains(.dryAir) == false ? "humidity" : nil
        ].compactMap { $0 }
        guard fine.isEmpty == false else { return [] }
        let list = fine.count == 1 ? fine[0] : fine.dropLast().joined(separator: ", ") + " and " + fine[fine.count - 1]
        return ["No other problems: \(list) \(fine.count == 1 ? "is" : "are") all fine."]
    }

    private static func range(
        _ statistics: PlantHistorySummary.Statistics,
        _ format: (Double) -> String
    ) -> String {
        "min \(format(statistics.minimum)), average \(format(statistics.average)), max \(format(statistics.maximum))"
    }

    private static func describe(_ mood: PlantMood) -> String {
        switch mood {
        case .happy: "happy: everything is fine, you feel great"
        case .thirsty: "thirsty: your SOIL is dry (this is about water in the pot, not the air), you'd like water soon"
        case .veryThirsty: "very thirsty: your SOIL is very dry (this is about water in the pot, not the air), you need water now"
        case .drowning: "drowning: the soil is too wet, you need to dry out"
        case .tooDark: "too dark: there is not enough light"
        case .tooHot: "too hot: the room is too warm"
        case .tooCold: "too cold: the room is too chilly"
        case .dryAir: "dry air: the AIR in the room is dry (this is about humidity, not your soil; you do NOT need water)"
        case .offline: "offline: you can't feel your sensor, so what you know may be old"
        }
    }

    private static func describe(_ purpose: PlantVoiceLineRequest.Purpose) -> String {
        switch purpose {
        case .home: "your speech bubble on the home screen"
        case .notification: "a notification telling the person how you feel"
        case .greeting: "greeting the person when they open the chat"
        }
    }
}
