import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorThanksLinesTests: PlantMonitorXCTestCase {
    func test_lines_haveAtLeastFourLocalisedLines() {
        let lines = PlantMonitorThanksLines.lines()

        XCTAssertGreaterThanOrEqual(lines.count, 4)
        lines.forEach { XCTAssertFalse($0.hasPrefix("plant.monitor.thanks."), "Missing string: \($0)") }
    }

    func test_next_neverRepeatsBackToBackWithAStuckRandomIndex() {
        var sut = PlantMonitorThanksLines(randomIndex: { _ in 0 })
        let picks = (0..<20).map { _ in sut.next() }

        zip(picks, picks.dropFirst()).forEach { XCTAssertNotEqual($0, $1) }
    }

    func test_next_usesTheInjectedIndexWhenItDiffersFromTheLastOne() {
        var sut = PlantMonitorThanksLines(randomIndex: { _ in 2 })

        XCTAssertEqual(sut.next(), PlantMonitorThanksLines.lines()[2])
    }

    func test_next_clampsAnOutOfRangeIndex() {
        var sut = PlantMonitorThanksLines(randomIndex: { $0 + 5 })

        XCTAssertTrue(PlantMonitorThanksLines.lines().contains(sut.next()))
    }
}
