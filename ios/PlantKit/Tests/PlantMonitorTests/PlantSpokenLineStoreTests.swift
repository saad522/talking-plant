import PlantShared
import XCTest
@testable import PlantMonitor

@MainActor
final class PlantSpokenLineStoreTests: PlantMonitorXCTestCase {
    func test_init_hasNothingSaved() {
        let sut = PlantSpokenLineStore(defaults: DefaultsSpy())

        XCTAssertNil(sut.mood)
        XCTAssertNil(sut.day)
    }

    func test_save_isLoadedByANewStoreOnTheSameDefaults() {
        let defaults = DefaultsSpy()
        PlantSpokenLineStore(defaults: defaults).save(mood: .veryThirsty, day: "2026-10-15")

        let sut = PlantSpokenLineStore(defaults: defaults)

        XCTAssertEqual(sut.mood, .veryThirsty)
        XCTAssertEqual(sut.day, "2026-10-15")
    }

    func test_save_roundTripsEveryMood() {
        let defaults = DefaultsSpy()
        let sut = PlantSpokenLineStore(defaults: defaults)

        for mood in PlantMood.allCases {
            sut.save(mood: mood, day: "2026-10-15")
            XCTAssertEqual(PlantSpokenLineStore(defaults: defaults).mood, mood)
        }
    }

    func test_mood_isNilWhenSavedValueIsUnknown() {
        let defaults = DefaultsSpy()
        defaults.set("confused", forKey: "plant.monitor.spoken.mood")

        XCTAssertNil(PlantSpokenLineStore(defaults: defaults).mood)
    }

    func test_day_usesTheCalendarsLocalDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 2 * 3_600)!
        // 2026-10-14 23:30 UTC is already the 15th at UTC+2.
        let date = Date(timeIntervalSince1970: 1_792_020_600)

        XCTAssertEqual(PlantSpokenLineStore.day(for: date, calendar: calendar), "2026-10-15")
    }
}
