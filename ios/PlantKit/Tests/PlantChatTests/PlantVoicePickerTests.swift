import XCTest
@testable import PlantChat

@MainActor
final class PlantVoicePickerTests: PlantChatXCTestCase {
    func test_voice_withPreferredInstalled_picksItEvenIfBetterQualityExists() {
        let preferred = makeVoice(identifier: "preferred", quality: .standard)
        let premium = makeVoice(identifier: "premium", quality: .premium)

        XCTAssertEqual(pick(preferred: "preferred", among: [premium, preferred]), preferred)
    }

    func test_voice_withPreferredNotInstalled_ignoresIt() {
        let premium = makeVoice(identifier: "premium", quality: .premium)

        XCTAssertEqual(pick(preferred: "missing", among: [premium]), premium)
    }

    func test_voice_ranksPremiumOverEnhancedOverStandard() {
        let standard = makeVoice(identifier: "standard", name: "A", quality: .standard)
        let enhanced = makeVoice(identifier: "enhanced", name: "B", quality: .enhanced)
        let premium = makeVoice(identifier: "premium", name: "C", quality: .premium)

        XCTAssertEqual(pick(among: [standard, premium, enhanced]), premium)
        XCTAssertEqual(pick(among: [standard, enhanced]), enhanced)
    }

    func test_voice_neverPicksOtherLanguageOverStyleLanguage() {
        let gb = makeVoice(identifier: "gb", language: "en-GB", quality: .premium)
        let us = makeVoice(identifier: "us", language: "en-US", quality: .standard)

        XCTAssertEqual(pick(language: "en-US", among: [gb, us]), us)
    }

    func test_voice_withEqualQuality_picksFirstByName() {
        let zoe = makeVoice(identifier: "zoe", name: "Zoe", quality: .enhanced)
        let ava = makeVoice(identifier: "ava", name: "Ava", quality: .enhanced)

        XCTAssertEqual(pick(among: [zoe, ava]), ava)
    }

    func test_voice_withNoVoiceInLanguage_picksBestEnUS() {
        let compact = makeVoice(identifier: "compact", language: "en-US", quality: .standard)
        let premium = makeVoice(identifier: "premium", language: "en-US", quality: .premium)
        let fr = makeVoice(identifier: "fr", language: "fr-FR", quality: .premium)

        XCTAssertEqual(pick(language: "en-AU", among: [compact, fr, premium]), premium)
    }

    func test_voice_withNothingSuitable_returnsNil() {
        XCTAssertNil(pick(among: []))
        XCTAssertNil(pick(among: [makeVoice(identifier: "fr", language: "fr-FR")]))
    }

    // MARK: - Helpers

    private func pick(
        language: String = "en-US",
        preferred: String? = nil,
        among voices: [PlantSynthesisVoice]
    ) -> PlantSynthesisVoice? {
        let style = PlantSpeechStyle(
            language: language, rate: 0.5, pitchCents: 0, effectRate: 1, preferredVoiceIdentifier: preferred
        )
        return PlantVoicePicker.voice(for: style, among: voices)
    }
}
