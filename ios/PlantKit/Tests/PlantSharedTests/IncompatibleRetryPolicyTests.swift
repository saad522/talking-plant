import XCTest
@testable import PlantShared

final class IncompatibleRetryPolicyTests: PlantSharedXCTestCase {
    func test_shouldRetry_allowsOneRetryThenStops() {
        var sut = IncompatibleRetryPolicy()

        XCTAssertTrue(sut.shouldRetry())
        XCTAssertFalse(sut.shouldRetry())
        XCTAssertFalse(sut.shouldRetry())
    }

    func test_reset_allowsRetryAgain() {
        var sut = IncompatibleRetryPolicy()
        _ = sut.shouldRetry()

        sut.reset()

        XCTAssertTrue(sut.shouldRetry())
    }
}
