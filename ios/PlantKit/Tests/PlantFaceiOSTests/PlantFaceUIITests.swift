import PlantFace
import PlantFaceiOS
import PlantShared
import XCTest

@MainActor
final class PlantFaceUIITests: PlantFaceiOSXCTestCase {
    func test_composed_rendersTwoEyesMatchingMoodExpression() {
        let expected: [PlantMood: PlantFaceEyes] = [
            .happy: .open,
            .thirsty: .droopy,
            .veryThirsty: .droopy,
            .drowning: .wide,
            .tooDark: .wide,
            .tooHot: .squint,
            .tooCold: .squint,
            .dryAir: .open,
            .offline: .closed,
        ]

        PlantMood.allCases.forEach { mood in
            let sut = PlantFaceUIComposer.composed(mood: mood)

            XCTAssertEqual(sut.renderedEyes(), [expected[mood]!, expected[mood]!], "\(mood)")
        }
    }

    func test_composed_rendersMouthMatchingMoodExpression() {
        let expected: [PlantMood: (curve: Double, isOpen: Bool)] = [
            .happy: (1, false),
            .thirsty: (-0.4, false),
            .veryThirsty: (-1, true),
            .drowning: (-0.6, true),
            .tooDark: (-0.2, false),
            .tooHot: (-0.5, true),
            .tooCold: (-0.5, false),
            .dryAir: (-0.3, false),
            .offline: (0, false),
        ]

        PlantMood.allCases.forEach { mood in
            let mouth = PlantFaceUIComposer.composed(mood: mood).renderedMouth()

            XCTAssertEqual(mouth?.curve, expected[mood]?.curve, "\(mood)")
            XCTAssertEqual(mouth?.isOpen, expected[mood]?.isOpen, "\(mood)")
        }
    }
}
