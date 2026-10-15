import PlantShared
import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorShakeLinesTests: PlantMonitorXCTestCase {
    func test_lines_haveAtLeastTwoLocalisedLinesForEveryMoodAndSleeping() {
        for mood in PlantMood.allCases {
            for isSleeping in [false, true] {
                let lines = PlantMonitorShakeLines.lines(for: mood, isSleeping: isSleeping)
                XCTAssertGreaterThanOrEqual(lines.count, 2, "\(mood) sleeping: \(isSleeping)")
                lines.forEach { XCTAssertFalse($0.hasPrefix("plant.monitor.shake."), "Missing string: \($0)") }
            }
        }
    }

    func test_lines_thirstyAndVeryThirstySayTheSame() {
        XCTAssertEqual(
            PlantMonitorShakeLines.lines(for: .thirsty, isSleeping: false),
            PlantMonitorShakeLines.lines(for: .veryThirsty, isSleeping: false)
        )
    }

    func test_lines_sleepingUsesTheSleepingLinesForAnyMood() {
        let sleeping = PlantMonitorShakeLines.lines(for: .happy, isSleeping: true)

        PlantMood.allCases.forEach {
            XCTAssertEqual(PlantMonitorShakeLines.lines(for: $0, isSleeping: true), sleeping)
        }
        XCTAssertNotEqual(sleeping, PlantMonitorShakeLines.lines(for: .happy, isSleeping: false))
    }

    func test_next_neverRepeatsBackToBackWithAStuckRandomIndex() {
        for mood in PlantMood.allCases {
            var sut = PlantMonitorShakeLines(randomIndex: { _ in 0 })
            let picks = (0..<20).map { _ in sut.next(for: mood, isSleeping: false) }

            zip(picks, picks.dropFirst()).forEach { XCTAssertNotEqual($0, $1, "\(mood)") }
        }
    }

    func test_next_usesTheInjectedIndexWhenItDiffersFromTheLastOne() {
        var sut = PlantMonitorShakeLines(randomIndex: { _ in 1 })
        let lines = PlantMonitorShakeLines.lines(for: .happy, isSleeping: false)

        XCTAssertEqual(sut.next(for: .happy, isSleeping: false), lines[1])
    }

    func test_next_remembersTheLastLinePerGroup() {
        var sut = PlantMonitorShakeLines(randomIndex: { _ in 0 })
        let happy = PlantMonitorShakeLines.lines(for: .happy, isSleeping: false)
        let dark = PlantMonitorShakeLines.lines(for: .tooDark, isSleeping: false)

        XCTAssertEqual(sut.next(for: .happy, isSleeping: false), happy[0])
        XCTAssertEqual(sut.next(for: .tooDark, isSleeping: false), dark[0])
    }

    func test_next_clampsAnOutOfRangeIndex() {
        var sut = PlantMonitorShakeLines(randomIndex: { $0 + 5 })
        let lines = PlantMonitorShakeLines.lines(for: .happy, isSleeping: false)

        XCTAssertTrue(lines.contains(sut.next(for: .happy, isSleeping: false)))
    }
}
