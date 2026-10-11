import PlantShared
import XCTest
@testable import PlantFace

@MainActor
final class PlantFaceViewModelTests: PlantFaceXCTestCase {
    func test_init_deliversExpressionForEveryMood() {
        let expected: [PlantMood: Expression] = [
            .happy: Expression(eyes: .open, mouthCurve: 1, isMouthOpen: false, blinks: true),
            .thirsty: Expression(eyes: .droopy, mouthCurve: -0.4, isMouthOpen: false, blinks: true),
            .veryThirsty: Expression(eyes: .droopy, mouthCurve: -1, isMouthOpen: true, blinks: true),
            .drowning: Expression(eyes: .wide, mouthCurve: -0.6, isMouthOpen: true, blinks: true),
            .tooDark: Expression(eyes: .wide, mouthCurve: -0.2, isMouthOpen: false, blinks: true),
            .tooHot: Expression(eyes: .squint, mouthCurve: -0.5, isMouthOpen: true, blinks: true),
            .tooCold: Expression(eyes: .squint, mouthCurve: -0.5, isMouthOpen: false, blinks: true),
            .dryAir: Expression(eyes: .open, mouthCurve: -0.3, isMouthOpen: false, blinks: true),
            .offline: Expression(eyes: .closed, mouthCurve: 0, isMouthOpen: false, blinks: false),
        ]

        PlantMood.allCases.forEach { mood in
            XCTAssertEqual(Expression(PlantFaceViewModel(mood: mood)), expected[mood], "\(mood)")
        }
    }

    func test_init_keepsMouthCurveWithinRangeForEveryMood() {
        PlantMood.allCases.forEach { mood in
            XCTAssertTrue((-1.0...1.0).contains(PlantFaceViewModel(mood: mood).mouthCurve), "\(mood)")
        }
    }

    func test_init_onlyOfflineStopsBlinking() {
        let nonBlinking = PlantMood.allCases.filter { !PlantFaceViewModel(mood: $0).blinks }

        XCTAssertEqual(nonBlinking, [.offline])
    }

    // MARK: - Private helpers

    private struct Expression: Equatable {
        let eyes: PlantFaceEyes
        let mouthCurve: Double
        let isMouthOpen: Bool
        let blinks: Bool

        init(eyes: PlantFaceEyes, mouthCurve: Double, isMouthOpen: Bool, blinks: Bool) {
            self.eyes = eyes
            self.mouthCurve = mouthCurve
            self.isMouthOpen = isMouthOpen
            self.blinks = blinks
        }

        init(_ viewModel: PlantFaceViewModel) {
            self.init(
                eyes: viewModel.eyes,
                mouthCurve: viewModel.mouthCurve,
                isMouthOpen: viewModel.isMouthOpen,
                blinks: viewModel.blinks
            )
        }
    }
}
