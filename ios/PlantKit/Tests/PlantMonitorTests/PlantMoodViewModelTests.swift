import PlantShared
import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMoodViewModelTests: PlantMonitorXCTestCase {
    func test_init_deliversLocalisedLabelForEachMood() {
        let expected: [PlantMood: String] = [
            .happy: "Happy",
            .thirsty: "Thirsty",
            .veryThirsty: "Very thirsty",
            .drowning: "Drowning",
            .tooDark: "Too dark",
            .tooHot: "Too hot",
            .tooCold: "Too cold",
            .dryAir: "Dry air",
            .offline: "Offline",
        ]

        PlantMood.allCases.forEach { mood in
            XCTAssertEqual(PlantMoodViewModel(mood: mood).label, expected[mood], "\(mood)")
        }
    }

    func test_init_deliversLocalisedSpeechForEachMood() {
        let expected: [PlantMood: String] = [
            .happy: "Feeling great today!",
            .thirsty: "I could use a drink soon.",
            .veryThirsty: "Water, please! I'm parched.",
            .drowning: "Too much water! Let me dry out.",
            .tooDark: "It's a bit dark in here.",
            .tooHot: "Phew, it's hot in here.",
            .tooCold: "Brr, I'm a little cold.",
            .dryAir: "The air feels so dry.",
            .offline: "Zzz… I can't feel my sensor.",
        ]

        PlantMood.allCases.forEach { mood in
            XCTAssertEqual(PlantMoodViewModel(mood: mood).speech, expected[mood], "\(mood)")
        }
    }
}
