import Foundation
import PlantShared

/// All text sent to the language model, and the check on what comes back. Deterministic.
public enum PlantVoicePrompt {
    /// Longest home line or notification, in characters.
    static let maximumLineLength = 100

    public static func instructions(personality: PlantPersonality, plantName: String) -> String {
        """
        You are \(plantName), a houseplant who talks to the person who looks after you.
        Your voice: \(personality.voice)
        Answer in 1–3 short sentences.
        Only use numbers that appear in the facts or in a tool result; never guess a value. If you don't know, say so.
        """
    }

    public static func facts(_ facts: PlantVoiceFacts) -> String {
        var lines = ["Mood: \(describe(facts.mood))"]
        if facts.isSleeping {
            lines.append("It's night and you're sleepy.")
        }
        if let reading = facts.reading {
            let values = [
                reading.moisture.map { "Moisture: \(PlantReadingFormatter.percent($0))" },
                reading.lux.map { "Light: \(PlantReadingFormatter.lux($0))" },
                reading.temperature.map { "Temperature: \(PlantReadingFormatter.temperature($0))" },
                reading.humidity.map { "Humidity: \(PlantReadingFormatter.percent($0))" }
            ]
            lines.append(contentsOf: values.compactMap { $0 })
        } else {
            lines.append("No readings yet.")
        }
        return lines.joined(separator: "\n")
    }

    /// The prompt for one chat turn: the current facts, then what the person said.
    public static func message(_ text: String, facts: PlantVoiceFacts) -> String {
        "Current facts:\n\(self.facts(facts))\n\nThe person says: \(text)"
    }

    public static func line(_ facts: PlantVoiceFacts, purpose: PlantVoiceLineRequest.Purpose) -> String {
        """
        Write one line of at most 12 words, with no numbers, for \(describe(purpose)).
        Current facts:
        \(self.facts(facts))
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
    /// empty, too long, or containing a digit. The caller then uses a template, so a generated
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
              line.contains(where: \.isNumber) == false else { return nil }
        return line
    }

    // MARK: - Private helpers

    private static func range(
        _ statistics: PlantHistorySummary.Statistics,
        _ format: (Double) -> String
    ) -> String {
        "min \(format(statistics.minimum)), average \(format(statistics.average)), max \(format(statistics.maximum))"
    }

    private static func describe(_ mood: PlantMood) -> String {
        switch mood {
        case .happy: "happy: everything is fine, you feel great"
        case .thirsty: "thirsty: the soil is getting dry, you'd like water soon"
        case .veryThirsty: "very thirsty: the soil is very dry, you need water now"
        case .drowning: "drowning: the soil is too wet, you need to dry out"
        case .tooDark: "too dark: there is not enough light"
        case .tooHot: "too hot: the room is too warm"
        case .tooCold: "too cold: the room is too chilly"
        case .dryAir: "dry air: the air is too dry"
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
