import XCTest
import PlantShared
@testable import PlantChat

final class PlantSpeechStyleTests: XCTestCase {
    func test_speechStyle_matchesTablePerPersonality() {
        let expected: [PlantPersonality: PlantSpeechStyle] = [
            .cheerful: PlantSpeechStyle(language: "en-US", rate: 0.50, speed: 1.00),
            .dramatic: PlantSpeechStyle(language: "en-US", rate: 0.46, speed: 0.95),
            .grumpyGrandma: PlantSpeechStyle(language: "en-IE", rate: 0.42, speed: 0.95),
            .chillSurfer: PlantSpeechStyle(language: "en-AU", rate: 0.46, speed: 0.90),
            .politeButler: PlantSpeechStyle(language: "en-GB", rate: 0.48, speed: 1.00),
        ]

        XCTAssertEqual(Set(expected.keys), Set(PlantPersonality.allCases))
        PlantPersonality.allCases.forEach { personality in
            XCTAssertEqual(personality.speechStyle, expected[personality], "\(personality)")
        }
    }

    func test_init_defaultsToNoPreferredVoice() {
        let sut = PlantSpeechStyle(language: "en-US", rate: 0.5, speed: 1)

        XCTAssertNil(sut.preferredVoiceIdentifier)
    }

    func test_adjusted_withNilMood_isUnchanged() {
        let base = base()

        XCTAssertEqual(base.adjusted(for: nil), base)
    }

    func test_adjusted_withNeutralMoods_isUnchanged() {
        let base = base()

        [PlantMood.tooDark, .dryAir, .offline].forEach { mood in
            XCTAssertEqual(base.adjusted(for: mood), base, "\(mood)")
        }
    }

    func test_adjusted_happy_isFaster() {
        let base = base()

        let sut = base.adjusted(for: .happy)

        XCTAssertEqual(sut.speed, 1.05, accuracy: 0.001)
    }

    func test_adjusted_lowMoods_areSlower() {
        let base = base()

        [PlantMood.thirsty, .veryThirsty, .tooHot, .tooCold].forEach { mood in
            let sut = base.adjusted(for: mood)

            XCTAssertEqual(sut.speed, 0.92, accuracy: 0.001, "\(mood)")
        }
    }

    func test_adjusted_drowning_isSlower() {
        let base = base()

        let sut = base.adjusted(for: .drowning)

        XCTAssertEqual(sut.speed, 0.90, accuracy: 0.001)
    }

    func test_adjusted_keepsLanguageRateAndPreferredVoice() {
        let base = PlantSpeechStyle(language: "en-GB", rate: 0.48, speed: 1, preferredVoiceIdentifier: "voice.id")

        let sut = base.adjusted(for: .happy)

        XCTAssertEqual(sut.language, "en-GB")
        XCTAssertEqual(sut.rate, 0.48)
        XCTAssertEqual(sut.preferredVoiceIdentifier, "voice.id")
    }

    func test_adjusted_clampsOutOfRangeValues() {
        let high = PlantSpeechStyle(language: "en-US", rate: 1.5, speed: 3)
        let low = PlantSpeechStyle(language: "en-US", rate: -1, speed: 0.1)

        XCTAssertEqual(high.adjusted(for: nil), PlantSpeechStyle(language: "en-US", rate: 1, speed: 2))
        XCTAssertEqual(low.adjusted(for: nil), PlantSpeechStyle(language: "en-US", rate: 0, speed: 0.5))
    }

    // MARK: - Helpers

    private func base() -> PlantSpeechStyle {
        PlantSpeechStyle(language: "en-US", rate: 0.5, speed: 1)
    }
}
