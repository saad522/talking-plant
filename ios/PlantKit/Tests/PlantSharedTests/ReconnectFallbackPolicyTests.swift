import XCTest
@testable import PlantShared

final class ReconnectFallbackPolicyTests: PlantSharedXCTestCase {
    func test_delayElapsed_whileConnectingToTarget_startsScan() {
        var sut = ReconnectFallbackPolicy()

        XCTAssertTrue(sut.delayElapsed(hasTarget: true, isConnecting: true))
        XCTAssertTrue(sut.isScanning)
    }

    func test_delayElapsed_afterConnected_doesNotStartScan() {
        var sut = ReconnectFallbackPolicy()

        XCTAssertFalse(sut.delayElapsed(hasTarget: true, isConnecting: false))
        XCTAssertFalse(sut.isScanning)
    }

    func test_delayElapsed_withoutTarget_doesNotStartScan() {
        var sut = ReconnectFallbackPolicy()

        XCTAssertFalse(sut.delayElapsed(hasTarget: false, isConnecting: true))
        XCTAssertFalse(sut.isScanning)
    }

    func test_delayElapsed_whenAlreadyScanning_doesNotStartAgain() {
        var sut = ReconnectFallbackPolicy()
        _ = sut.delayElapsed(hasTarget: true, isConnecting: true)

        XCTAssertFalse(sut.delayElapsed(hasTarget: true, isConnecting: true))
    }

    func test_reset_stopsScanAndAllowsStartAgain() {
        var sut = ReconnectFallbackPolicy()
        _ = sut.delayElapsed(hasTarget: true, isConnecting: true)

        sut.reset()

        XCTAssertFalse(sut.isScanning)
        XCTAssertTrue(sut.delayElapsed(hasTarget: true, isConnecting: true))
    }

    func test_shouldAdopt_beforeScanStarts_isFalse() {
        let sut = ReconnectFallbackPolicy()

        XCTAssertFalse(sut.shouldAdopt(advertisedIdentifier: UUID(), advertisedName: "TalkingPlant-TEST", pending: UUID(), targetName: "TalkingPlant-TEST"))
    }

    func test_shouldAdopt_sameNameNewIdentifier_isTrue() {
        let sut = scanningSUT()

        XCTAssertTrue(sut.shouldAdopt(advertisedIdentifier: UUID(), advertisedName: "TalkingPlant-TEST", pending: UUID(), targetName: "TalkingPlant-TEST"))
    }

    func test_shouldAdopt_sameIdentifier_isFalse() {
        let sut = scanningSUT()
        let identifier = UUID()

        XCTAssertFalse(sut.shouldAdopt(advertisedIdentifier: identifier, advertisedName: "TalkingPlant-TEST", pending: identifier, targetName: "TalkingPlant-TEST"))
    }

    func test_shouldAdopt_otherNameOrNoName_isFalse() {
        let sut = scanningSUT()

        XCTAssertFalse(sut.shouldAdopt(advertisedIdentifier: UUID(), advertisedName: "TalkingPlant-OTHER", pending: UUID(), targetName: "TalkingPlant-TEST"))
        XCTAssertFalse(sut.shouldAdopt(advertisedIdentifier: UUID(), advertisedName: nil, pending: UUID(), targetName: "TalkingPlant-TEST"))
    }

    // MARK: - Helpers

    private func scanningSUT() -> ReconnectFallbackPolicy {
        var sut = ReconnectFallbackPolicy()
        _ = sut.delayElapsed(hasTarget: true, isConnecting: true)
        return sut
    }
}
