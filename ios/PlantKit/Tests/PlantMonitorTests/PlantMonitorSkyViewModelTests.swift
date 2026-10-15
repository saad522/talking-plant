import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorSkyViewModelTests: PlantMonitorXCTestCase {
    func test_body_isSunForDayAndThirstyAndMoonForNight() {
        XCTAssertEqual(makeSUT(.day, hour: 12).body, .sun)
        XCTAssertEqual(makeSUT(.thirsty, hour: 12).body, .sun)
        XCTAssertEqual(makeSUT(.night, hour: 12).body, .moon)
    }

    func test_sunProgress_runsFromSixToEighteen() {
        XCTAssertEqual(makeSUT(.day, hour: 6).progress, 0, accuracy: 0.0001)
        XCTAssertEqual(makeSUT(.day, hour: 12).progress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(makeSUT(.day, hour: 18).progress, 1, accuracy: 0.0001)
    }

    func test_sunProgress_waitsAtNearestEndOutsideItsHours() {
        XCTAssertEqual(makeSUT(.day, hour: 3).progress, 0, accuracy: 0.0001)
        XCTAssertEqual(makeSUT(.day, hour: 22).progress, 1, accuracy: 0.0001)
        XCTAssertEqual(makeSUT(.thirsty, hour: 22).progress, 1, accuracy: 0.0001)
    }

    func test_moonProgress_runsFromEighteenToSix() {
        XCTAssertEqual(makeSUT(.night, hour: 18).progress, 0, accuracy: 0.0001)
        XCTAssertEqual(makeSUT(.night, hour: 0).progress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(makeSUT(.night, hour: 6).progress, 1, accuracy: 0.0001)
    }

    func test_moonProgress_waitsAtEndDuringTheDay() {
        XCTAssertEqual(makeSUT(.night, hour: 12).progress, 1, accuracy: 0.0001)
        XCTAssertEqual(makeSUT(.night, hour: 14).progress, 1, accuracy: 0.0001)
    }

    func test_progress_usesCalendarTimeZone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3 * 3_600)!
        let utcNoon = Date(timeIntervalSince1970: 12 * 3_600)

        let sut = PlantMonitorSkyViewModel(scene: .day, date: utcNoon, calendar: calendar)

        XCTAssertEqual(sut.progress, 0.75, accuracy: 0.0001)
    }

    // MARK: - Private helpers

    private func makeSUT(_ scene: PlantMonitorScene, hour: Int) -> PlantMonitorSkyViewModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = Date(timeIntervalSince1970: TimeInterval(hour * 3_600))
        return PlantMonitorSkyViewModel(scene: scene, date: date, calendar: calendar)
    }
}
