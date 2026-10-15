import XCTest
@testable import PlantIntro

@MainActor
final class PlantIntroTimelineTests: PlantIntroXCTestCase {
    func test_pose_startsAndEndsAtRest() {
        XCTAssertEqual(PlantIntroTimeline.pose(at: 0), .rest)
        XCTAssertEqual(PlantIntroTimeline.pose(at: 0.5), .rest)
        XCTAssertEqual(PlantIntroTimeline.pose(at: 1.3), .rest)
        XCTAssertEqual(PlantIntroTimeline.pose(at: -1), .rest)
    }

    func test_pose_squashesBeforeJumpingAndStretchesInTheAir() {
        let anticipation = PlantIntroTimeline.pose(at: 0.08)
        XCTAssertLessThan(anticipation.scaleY, 1)
        XCTAssertGreaterThan(anticipation.scaleX, 1)

        let airborne = PlantIntroTimeline.pose(at: 0.22)
        XCTAssertGreaterThan(airborne.scaleY, 1)
        XCTAssertLessThan(airborne.scaleX, 1)
        XCTAssertLessThan(airborne.offsetY, 0)
    }

    func test_pose_wigglesTheLeavesAndSettles() {
        let rotations = stride(from: 0.02, to: 0.48, by: 0.02).map { PlantIntroTimeline.pose(at: $0).rotation }

        XCTAssertTrue(rotations.contains { $0 > 0.5 })
        XCTAssertTrue(rotations.contains { $0 < -0.5 })
        XCTAssertEqual(PlantIntroTimeline.pose(at: 0.5).rotation, 0)
    }

    func test_isBlinking_blinksOnceForOneHundredTwentyMilliseconds() {
        let samples = (0...160).map { PlantIntroTimeline.isBlinking(at: Double($0) / 100) }

        XCTAssertFalse(PlantIntroTimeline.isBlinking(at: 0))
        XCTAssertTrue(PlantIntroTimeline.isBlinking(at: 0.3))
        XCTAssertFalse(PlantIntroTimeline.isBlinking(at: 0.4))
        XCTAssertEqual(samples.filter { $0 }.count, 12)
    }

    func test_glow_pulsesOnceBetweenTwoTenthsAndOneSecond() {
        XCTAssertEqual(PlantIntroTimeline.glow(at: 0.1), 0)
        XCTAssertEqual(PlantIntroTimeline.glow(at: 0.2), 0, accuracy: 0.0001)
        XCTAssertEqual(PlantIntroTimeline.glow(at: 0.6), 1, accuracy: 0.0001)
        XCTAssertEqual(PlantIntroTimeline.glow(at: 1.0), 0, accuracy: 0.0001)
        XCTAssertEqual(PlantIntroTimeline.glow(at: 1.4), 0)
    }

    func test_textProgress_risesBetweenFourTenthsAndOneSecond() {
        XCTAssertEqual(PlantIntroTimeline.textProgress(at: 0.2), 0)
        XCTAssertEqual(PlantIntroTimeline.textProgress(at: 0.4), 0)
        XCTAssertEqual(PlantIntroTimeline.textProgress(at: 1.0), 1)
        XCTAssertEqual(PlantIntroTimeline.textProgress(at: 1.5), 1)

        let samples = (8...20).map { PlantIntroTimeline.textProgress(at: Double($0) / 20) }
        XCTAssertEqual(samples, samples.sorted())
    }
}
