import Foundation
import PlantShared

/// Fixed texts for when the language model is unavailable or its line can't be used.
enum PlantChatTemplate {
    static var greeting: String {
        String.localised(key: "plant.chat.greeting.speech")
    }

    static func speech(mood: PlantMood, isSleeping: Bool) -> String {
        guard isSleeping == false else { return String.localised(key: "plant.chat.sleeping.speech") }
        return switch mood {
        case .happy: String.localised(key: "plant.chat.mood.happy.speech")
        case .thirsty: String.localised(key: "plant.chat.mood.thirsty.speech")
        case .veryThirsty: String.localised(key: "plant.chat.mood.veryThirsty.speech")
        case .drowning: String.localised(key: "plant.chat.mood.drowning.speech")
        case .tooDark: String.localised(key: "plant.chat.mood.tooDark.speech")
        case .tooHot: String.localised(key: "plant.chat.mood.tooHot.speech")
        case .tooCold: String.localised(key: "plant.chat.mood.tooCold.speech")
        case .dryAir: String.localised(key: "plant.chat.mood.dryAir.speech")
        case .offline: String.localised(key: "plant.chat.mood.offline.speech")
        }
    }

    /// The mood line followed by the latest values, e.g. "I could use a drink soon. Right now: moisture 24%."
    static func reply(facts: PlantVoiceFacts?) -> String {
        guard let facts else { return String.localised(key: "plant.chat.reply.unknown") }
        return speech(mood: facts.mood, isSleeping: facts.isSleeping) + " " + status(of: facts.reading)
    }

    private static func status(of reading: PlantReading?) -> String {
        guard let reading else { return String.localised(key: "plant.chat.reply.noReadings") }
        let values = [
            reading.moisture.map { String(format: String.localised(key: "plant.chat.reply.moisture"), PlantReadingFormatter.percent($0)) },
            reading.lux.map { String(format: String.localised(key: "plant.chat.reply.light"), PlantReadingFormatter.lux($0)) },
            reading.temperature.map { String(format: String.localised(key: "plant.chat.reply.temperature"), PlantReadingFormatter.temperature($0)) },
            reading.humidity.map { String(format: String.localised(key: "plant.chat.reply.humidity"), PlantReadingFormatter.percent($0)) }
        ].compactMap { $0 }
        guard values.isEmpty == false else { return String.localised(key: "plant.chat.reply.noReadings") }
        return String(format: String.localised(key: "plant.chat.reply.status"), values.joined(separator: ", "))
    }
}
