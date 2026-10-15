import PlantFaceiOS
import PlantShared
import XCTest

@MainActor
final class PlantFaceUIITests: PlantFaceiOSXCTestCase {
    func test_composed_rendersOneEyeSetMatchingMood() {
        let expected: [PlantMood: PlantFaceEyeKind] = [
            .happy: .open,
            .drowning: .open,
            .thirsty: .lidded,
            .veryThirsty: .lidded,
            .dryAir: .lidded,
            .tooHot: .squint,
            .tooCold: .squint,
            .tooDark: .closed,
            .offline: .closed,
        ]

        PlantMood.allCases.forEach { mood in
            XCTAssertEqual(PlantFaceUIComposer.composed(mood: mood).renderedEyes(), [expected[mood]!], "\(mood)")
        }
    }

    func test_composed_rendersEffectsMatchingMood() {
        let expected: [PlantMood: Set<PlantFaceEffect>] = [
            .happy: [.sparkles],
            .thirsty: [.potCracks],
            .veryThirsty: [.potCracks],
            .dryAir: [],
            .tooHot: [.sweat],
            .tooCold: [.shiver],
            .tooDark: [.zzz],
            .offline: [.zzz],
            .drowning: [.drops, .puddle],
        ]

        PlantMood.allCases.forEach { mood in
            XCTAssertEqual(PlantFaceUIComposer.composed(mood: mood).renderedEffects(), expected[mood], "\(mood)")
        }
    }

    func test_composed_rendersPuddleOnlyForDrowning() {
        let withPuddle = PlantMood.allCases.filter {
            PlantFaceUIComposer.composed(mood: $0).renderedEffects().contains(.puddle)
        }

        XCTAssertEqual(withPuddle, [.drowning])
    }

    func test_composed_rendersDrySoilAndPotCracksOnlyForThirstyAndVeryThirsty() {
        let dry = PlantMood.allCases.filter { PlantFaceUIComposer.composed(mood: $0).renderedSoil() == [.dry] }
        let cracked = PlantMood.allCases.filter {
            PlantFaceUIComposer.composed(mood: $0).renderedEffects().contains(.potCracks)
        }

        XCTAssertEqual(dry, [.thirsty, .veryThirsty])
        XCTAssertEqual(cracked, [.thirsty, .veryThirsty])
    }

    func test_composed_rendersWetSoilForDrowningAndStandardSoilOtherwise() {
        PlantMood.allCases.filter { $0 != .thirsty && $0 != .veryThirsty }.forEach { mood in
            let expected: PlantFaceSoil = mood == .drowning ? .wet : .standard

            XCTAssertEqual(PlantFaceUIComposer.composed(mood: mood).renderedSoil(), [expected], "\(mood)")
        }
    }

    func test_composedSurprised_rendersOpenWideEyesAndFilledMouthForEveryMood() {
        PlantMood.allCases.forEach { mood in
            let sut = PlantFaceUIComposer.composed(mood: mood, isSurprised: true)

            XCTAssertEqual(sut.renderedEyes(), [.open], "\(mood)")
            XCTAssertEqual(sut.renderedEyeRy(), [11], "\(mood)")
            XCTAssertEqual(sut.renderedMouthFilled(), [true], "\(mood)")
        }
    }

    func test_composedSurprised_keepsTheMoodsEffectsAndSoil() {
        PlantMood.allCases.forEach { mood in
            let calm = PlantFaceUIComposer.composed(mood: mood)
            let sut = PlantFaceUIComposer.composed(mood: mood, isSurprised: true)

            XCTAssertEqual(sut.renderedEffects(), calm.renderedEffects(), "\(mood)")
            XCTAssertEqual(sut.renderedSoil(), calm.renderedSoil(), "\(mood)")
        }
    }

    func test_composedNotSurprised_rendersFilledMouthOnlyForDrowning() {
        let filled = PlantMood.allCases.filter {
            PlantFaceUIComposer.composed(mood: $0, isSurprised: false).renderedMouthFilled() == [true]
        }

        XCTAssertEqual(filled, [.drowning])
    }
}
