import PlantHistory
import PlantHistoryiOS
import XCTest

@MainActor
final class PlantHistoryHapticsUIITests: PlantHistoryiOSXCTestCase {
    func test_appearAndSamples_playNoHaptic() {
        let haptics = HapticsSpy()
        let (sut, loader) = makeSUT(haptics: haptics)

        sut.simulateAppear()
        loader.completeLoad(with: [makeSample()])

        XCTAssertEqual(haptics.played, [])
    }

    func test_rangeChange_playsSelectionAndStillLoadsRange() {
        let haptics = HapticsSpy()
        let (sut, loader) = makeSUT(haptics: haptics)
        sut.simulateAppear()

        sut.simulateSelecting(.week)

        XCTAssertEqual(haptics.played, [.selection])
        XCTAssertEqual(loader.messages, [.load(.day), .subscribe, .load(.week)])
    }
}
