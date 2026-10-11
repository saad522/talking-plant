import PlantShared
import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorSceneViewModelTests: PlantMonitorXCTestCase {
    // MARK: - Scene

    func test_scene_isNightBelowTenLuxAndDayFromTenLux() {
        XCTAssertEqual(makeSUT(lux: 9, mood: .happy).scene, .night)
        XCTAssertEqual(makeSUT(lux: 10, mood: .happy).scene, .day)
    }

    func test_scene_isNightWhenOfflineAtAnyLux() {
        XCTAssertEqual(makeSUT(lux: 5_000, mood: .offline).scene, .night)
        XCTAssertEqual(makeSUT(lux: nil, mood: .offline).scene, .night)
        XCTAssertEqual(makeSUT(reading: nil, mood: .offline).scene, .night)
    }

    func test_scene_isThirstyForThirstyAndVeryThirsty() {
        XCTAssertEqual(makeSUT(mood: .thirsty).scene, .thirsty)
        XCTAssertEqual(makeSUT(mood: .veryThirsty).scene, .thirsty)
    }

    func test_scene_isNightWhenDarkEvenIfThirsty() {
        XCTAssertEqual(makeSUT(lux: 0, mood: .thirsty).scene, .night)
        XCTAssertEqual(makeSUT(lux: 0, mood: .veryThirsty).scene, .night)
    }

    func test_scene_isDayWithoutData() {
        XCTAssertEqual(PlantMonitorSceneViewModel(reading: nil, mood: nil).scene, .day)
        XCTAssertEqual(makeSUT(lux: nil, mood: nil).scene, .day)
    }

    func test_scene_isDayForDryAir() {
        XCTAssertEqual(makeSUT(mood: .dryAir).scene, .day)
    }

    func test_scene_isDayForEveryOtherMoodWhenBright() {
        let others: [PlantMood] = [.happy, .drowning, .tooDark, .tooHot, .tooCold, .dryAir]

        others.forEach { mood in
            XCTAssertEqual(makeSUT(mood: mood).scene, .day, "\(mood)")
        }
    }

    // MARK: - Sensors

    func test_sensors_showHumidityInsteadOfTemperatureOnlyForDryAir() {
        PlantMood.allCases.forEach { mood in
            let expected: [PlantSensorKind] = mood == .dryAir
                ? [.moisture, .light, .humidity]
                : [.moisture, .light, .temperature]

            XCTAssertEqual(makeSUT(mood: mood).sensors, expected, "\(mood)")
        }
    }

    func test_sensors_showTemperatureBeforeMoodLoads() {
        XCTAssertEqual(makeSUT(mood: nil).sensors, [.moisture, .light, .temperature])
    }

    // MARK: - Warnings

    func test_warnings_followMood() {
        PlantMood.allCases.forEach { mood in
            let expected: [PlantSensorKind] = switch mood {
            case .thirsty, .veryThirsty: [.moisture]
            case .dryAir: [.humidity]
            default: []
            }

            XCTAssertEqual(makeSUT(mood: mood).warnings, expected, "\(mood)")
        }
    }

    func test_warnings_stayAtNight() {
        XCTAssertEqual(makeSUT(lux: 0, mood: .thirsty).warnings, [.moisture])
        XCTAssertEqual(makeSUT(lux: 0, mood: .dryAir).warnings, [.humidity])
    }

    func test_warnings_areEmptyBeforeMoodLoads() {
        XCTAssertEqual(makeSUT(mood: nil).warnings, [])
    }

    // MARK: - Private helpers

    private func makeSUT(lux: Int? = 1_000, mood: PlantMood?) -> PlantMonitorSceneViewModel {
        PlantMonitorSceneViewModel(reading: makeReading(lux: lux), mood: mood)
    }

    private func makeSUT(reading: PlantReading?, mood: PlantMood?) -> PlantMonitorSceneViewModel {
        PlantMonitorSceneViewModel(reading: reading, mood: mood)
    }
}
