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
}
