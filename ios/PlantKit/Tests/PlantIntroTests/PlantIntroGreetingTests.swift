import XCTest
@testable import PlantIntro

@MainActor
final class PlantIntroGreetingTests: PlantIntroXCTestCase {
    func test_period_coversEveryHourOfTheDay() {
        let expected: [Int: PlantIntroPeriod] = Dictionary(uniqueKeysWithValues: (0..<24).map { hour in
            switch hour {
            case 5...11: (hour, .morning)
            case 12...17: (hour, .afternoon)
            case 18...22: (hour, .evening)
            default: (hour, .night)
            }
        })

        (0..<24).forEach { hour in
            XCTAssertEqual(PlantIntroGreeting.period(for: hour), expected[hour], "hour \(hour)")
        }
    }

    func test_period_wrapsHoursOutsideADay() {
        XCTAssertEqual(PlantIntroGreeting.period(for: 24), .night)
        XCTAssertEqual(PlantIntroGreeting.period(for: 29), .morning)
        XCTAssertEqual(PlantIntroGreeting.period(for: -1), .night)
    }

    func test_greeting_deliversTheTextForEachPeriod() {
        XCTAssertEqual(PlantIntroGreeting.greeting(for: 5), "Good morning!")
        XCTAssertEqual(PlantIntroGreeting.greeting(for: 11), "Good morning!")
        XCTAssertEqual(PlantIntroGreeting.greeting(for: 12), "Good afternoon!")
        XCTAssertEqual(PlantIntroGreeting.greeting(for: 17), "Good afternoon!")
        XCTAssertEqual(PlantIntroGreeting.greeting(for: 18), "Good evening!")
        XCTAssertEqual(PlantIntroGreeting.greeting(for: 22), "Good evening!")
        XCTAssertEqual(PlantIntroGreeting.greeting(for: 23), "Shh... sweet dreams")
        XCTAssertEqual(PlantIntroGreeting.greeting(for: 0), "Shh... sweet dreams")
        XCTAssertEqual(PlantIntroGreeting.greeting(for: 4), "Shh... sweet dreams")
    }

    func test_title_deliversTheName() {
        XCTAssertEqual(PlantIntroGreeting.title, "Sprout")
    }

    func test_particleStyle_isFirefliesAtNightAndPollenByDay() {
        XCTAssertEqual(PlantIntroPeriod.morning.particleStyle, .pollen)
        XCTAssertEqual(PlantIntroPeriod.afternoon.particleStyle, .pollen)
        XCTAssertEqual(PlantIntroPeriod.evening.particleStyle, .fireflies)
        XCTAssertEqual(PlantIntroPeriod.night.particleStyle, .fireflies)
    }
}
