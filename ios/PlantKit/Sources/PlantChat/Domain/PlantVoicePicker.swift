public enum PlantVoicePicker {
    private static let fallbackLanguage = "en-US"

    public static func voice(for style: PlantSpeechStyle, among voices: [PlantSynthesisVoice]) -> PlantSynthesisVoice? {
        if let identifier = style.preferredVoiceIdentifier,
           let preferred = voices.first(where: { $0.identifier == identifier }) {
            return preferred
        }
        return best(in: style.language, among: voices) ?? best(in: fallbackLanguage, among: voices)
    }

    private static func best(in language: String, among voices: [PlantSynthesisVoice]) -> PlantSynthesisVoice? {
        voices
            .filter { $0.language == language }
            .min { lhs, rhs in
                lhs.quality != rhs.quality ? lhs.quality > rhs.quality : lhs.name < rhs.name
            }
    }
}
