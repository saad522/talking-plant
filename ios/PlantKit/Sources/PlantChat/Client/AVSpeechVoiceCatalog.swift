import AVFoundation

public enum AVSpeechVoiceCatalog {
    public static func installed() -> [PlantSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().compactMap { voice in
            guard !voice.voiceTraits.contains(.isNoveltyVoice),
                  !voice.voiceTraits.contains(.isPersonalVoice) else { return nil }
            return PlantSynthesisVoice(
                identifier: voice.identifier,
                name: voice.name,
                language: voice.language,
                quality: quality(of: voice)
            )
        }
    }

    public static func avVoice(for style: PlantSpeechStyle) -> AVSpeechSynthesisVoice? {
        if let picked = PlantVoicePicker.voice(for: style, among: installed()),
           let voice = AVSpeechSynthesisVoice(identifier: picked.identifier) {
            return voice
        }
        return AVSpeechSynthesisVoice(language: style.language) ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    private static func quality(of voice: AVSpeechSynthesisVoice) -> PlantSynthesisVoice.Quality {
        switch voice.quality {
        case .premium: .premium
        case .enhanced: .enhanced
        default: .standard
        }
    }
}
