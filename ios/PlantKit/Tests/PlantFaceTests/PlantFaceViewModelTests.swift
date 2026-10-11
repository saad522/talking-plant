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
}
