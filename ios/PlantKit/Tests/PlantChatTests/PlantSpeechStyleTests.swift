import XCTest
@testable import PlantChat

final class PlantSpeechStyleTests: XCTestCase {
    func test_speechStyle_matchesTablePerPersonality() {
        let expected: [PlantPersonality: PlantSpeechStyle] = [
            .cheerful: PlantSpeechStyle(language: "en-US", rate: 0.52, pitch: 1.15),
            .dramatic: PlantSpeechStyle(language: "en-US", rate: 0.46, pitch: 1.25),
            .grumpyGrandma: PlantSpeechStyle(language: "en-IE", rate: 0.42, pitch: 0.90),
            .chillSurfer: PlantSpeechStyle(language: "en-AU", rate: 0.44, pitch: 0.95),
            .politeButler: PlantSpeechStyle(language: "en-GB", rate: 0.48, pitch: 0.90),
        ]

        XCTAssertEqual(Set(expected.keys), Set(PlantPersonality.allCases))
        PlantPersonality.allCases.forEach { personality in
            XCTAssertEqual(personality.speechStyle, expected[personality], "\(personality)")
        }
    }
}
