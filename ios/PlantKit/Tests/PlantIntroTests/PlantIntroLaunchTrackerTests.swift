import XCTest
@testable import PlantIntro

@MainActor
final class PlantIntroLaunchTrackerTests: PlantIntroXCTestCase {
    func test_consume_isColdOnlyTheFirstTime() {
        let sut = PlantIntroLaunchTracker()

        XCTAssertTrue(sut.consumeColdLaunch())
        XCTAssertFalse(sut.consumeColdLaunch())
        XCTAssertFalse(sut.consumeColdLaunch())
    }

    func test_trackers_doNotShareState() {
        XCTAssertTrue(PlantIntroLaunchTracker().consumeColdLaunch())
        XCTAssertTrue(PlantIntroLaunchTracker().consumeColdLaunch())
    }
}
