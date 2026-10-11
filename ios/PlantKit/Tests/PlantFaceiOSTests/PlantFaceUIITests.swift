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
}
