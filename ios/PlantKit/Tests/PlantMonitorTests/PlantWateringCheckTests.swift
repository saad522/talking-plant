import XCTest
@testable import PlantMonitor

final class PlantWateringCheckTests: XCTestCase {
    func test_minimumRise_isTenPoints() {
        XCTAssertEqual(PlantWateringCheck.minimumRise, 10)
    }

    func test_window_isTenMinutes() {
        XCTAssertEqual(PlantWateringCheck.window, 600)
    }

    func test_isWatered_isTrueForARiseOfExactlyMinimum() {
        XCTAssertTrue(PlantWateringCheck.isWatered(baseline: 20, current: 30))
    }

    func test_isWatered_isTrueForABiggerRise() {
        XCTAssertTrue(PlantWateringCheck.isWatered(baseline: 20, current: 80))
    }

    func test_isWatered_isFalseForASmallerRise() {
        XCTAssertFalse(PlantWateringCheck.isWatered(baseline: 20, current: 29))
    }

    func test_isWatered_isFalseForAFall() {
        XCTAssertFalse(PlantWateringCheck.isWatered(baseline: 50, current: 20))
    }
}
