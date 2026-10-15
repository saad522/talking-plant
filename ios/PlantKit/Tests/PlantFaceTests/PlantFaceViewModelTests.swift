import PlantShared
import XCTest
@testable import PlantFace

@MainActor
final class PlantFaceViewModelTests: PlantFaceXCTestCase {
    func test_init_deliversStateForEveryMood() {
        let expected: [PlantMood: PlantFaceState] = [
            .happy: .happy,
            .thirsty: .thirsty,
            .veryThirsty: .thirsty,
            .dryAir: .thirsty,
            .tooHot: .hot,
            .tooCold: .cold,
            .tooDark: .asleep,
            .offline: .asleep,
            .drowning: .overwatered,
        ]

        PlantMood.allCases.forEach { mood in
            XCTAssertEqual(PlantFaceViewModel(mood: mood).state, expected[mood], "\(mood)")
        }
    }

    func test_init_drawsSleepingFaceMoodAsAsleep() {
        // PlantMonitorSceneViewModel.sleepingFaceMood is `.tooDark` (pinned in PlantMonitorTests).
        XCTAssertEqual(PlantFaceViewModel(mood: .tooDark).state, .asleep)
    }

    func test_init_setsDrySoilOnlyForThirstyAndVeryThirsty() {
        let drySoilMoods = PlantMood.allCases.filter { PlantFaceViewModel(mood: $0).drySoil }

        XCTAssertEqual(drySoilMoods, [.thirsty, .veryThirsty])
    }

    func test_init_addsExtraTiltOnlyForVeryThirsty() {
        PlantMood.allCases.forEach { mood in
            let expected: Double = mood == .veryThirsty ? 6 : 0

            XCTAssertEqual(PlantFaceViewModel(mood: mood).extraTilt, expected, "\(mood)")
        }
    }

    func test_init_blinksOnlyWhenEyesAreOpen() {
        let expected: [PlantFaceState: Bool] = [
            .happy: true,
            .thirsty: true,
            .overwatered: true,
            .hot: false,
            .cold: false,
            .asleep: false,
        ]

        PlantMood.allCases.forEach { mood in
            let sut = PlantFaceViewModel(mood: mood)

            XCTAssertEqual(sut.blinks, expected[sut.state], "\(mood)")
        }
    }

    func test_init_isNotSurprisedByDefault() {
        PlantMood.allCases.forEach { mood in
            XCTAssertFalse(PlantFaceViewModel(mood: mood).isSurprised, "\(mood)")
        }
    }

    func test_init_surprisedKeepsStateSoilAndTiltForEveryMood() {
        PlantMood.allCases.forEach { mood in
            let calm = PlantFaceViewModel(mood: mood)
            let sut = PlantFaceViewModel(mood: mood, isSurprised: true)

            XCTAssertTrue(sut.isSurprised, "\(mood)")
            XCTAssertEqual(sut.state, calm.state, "\(mood)")
            XCTAssertEqual(sut.drySoil, calm.drySoil, "\(mood)")
            XCTAssertEqual(sut.extraTilt, calm.extraTilt, "\(mood)")
        }
    }

    func test_init_surprisedNeverBlinks() {
        PlantMood.allCases.forEach { mood in
            XCTAssertFalse(PlantFaceViewModel(mood: mood, isSurprised: true).blinks, "\(mood)")
        }
    }
}
