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

    // MARK: - Water button

    func test_isWaterPrimary_isTrueForThirstyAndVeryThirstyByDayAndAtNight() {
        [5_000, 0].forEach { lux in
            XCTAssertTrue(makeSUT(lux: lux, mood: .thirsty).isWaterPrimary, "lux \(lux)")
            XCTAssertTrue(makeSUT(lux: lux, mood: .veryThirsty).isWaterPrimary, "lux \(lux)")
        }
    }

    func test_isWaterPrimary_isFalseForEveryOtherMood() {
        PlantMood.allCases.filter { $0 != .thirsty && $0 != .veryThirsty }.forEach { mood in
            XCTAssertFalse(makeSUT(mood: mood).isWaterPrimary, "day \(mood)")
            XCTAssertFalse(makeSUT(lux: 0, mood: mood).isWaterPrimary, "night \(mood)")
        }
        XCTAssertFalse(makeSUT(mood: nil).isWaterPrimary)
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

    // MARK: - Sleeping

    func test_isSleeping_isTrueOnlyForHappyAtNight() {
        PlantMood.allCases.forEach { mood in
            XCTAssertEqual(makeSUT(lux: 0, mood: mood).isSleeping, mood == .happy, "night \(mood)")
            XCTAssertFalse(makeSUT(lux: 1_000, mood: mood).isSleeping, "day \(mood)")
        }
        XCTAssertFalse(makeSUT(lux: 0, mood: nil).isSleeping)
    }

    func test_sleeping_deliversSleepingFaceMoodSpeechAndSubtitle() {
        let sut = makeSUT(lux: 0, mood: .happy)

        XCTAssertEqual(sut.faceMood, PlantMonitorSceneViewModel.sleepingFaceMood)
        XCTAssertEqual(sut.speech, "Zzz… see you at sunrise.")
        XCTAssertEqual(sut.header(name: "Sprout", room: "Living room").subtitle, "Living room · Sleeping")
    }

    func test_header_deliversConnectionSubtitle() {
        let sut = PlantMonitorSceneViewModel(reading: makeReading(), mood: .happy, connection: .connecting)

        XCTAssertEqual(sut.connection, .connecting)
        XCTAssertEqual(sut.header(name: "Sprout", room: "Living room").subtitle, "Living room · Connecting…")
    }

    func test_sleepingFaceMood_isTooDark_whichPlantFaceDrawsAsAsleep() {
        // PlantFaceTests pins `.tooDark` to the asleep state. PlantMonitor can't import PlantFace.
        XCTAssertEqual(PlantMonitorSceneViewModel.sleepingFaceMood, .tooDark)
    }

    func test_awake_deliversOwnMoodSpeechAndSubtitleAtNightAndByDay() {
        PlantMood.allCases.filter { $0 != .happy }.forEach { mood in
            [0, 1_000].forEach { lux in
                let sut = makeSUT(lux: lux, mood: mood)
                let expected = PlantMoodViewModel(mood: mood)

                XCTAssertEqual(sut.faceMood, mood, "\(mood) \(lux)")
                XCTAssertEqual(sut.speech, expected.speech, "\(mood) \(lux)")
                XCTAssertEqual(
                    sut.header(name: "Sprout", room: "Living room").subtitle,
                    "Living room · \(expected.label)",
                    "\(mood) \(lux)"
                )
            }
        }
    }

    func test_happyByDay_deliversHappyMoodAndSpeech() {
        let sut = makeSUT(lux: 1_000, mood: .happy)

        XCTAssertEqual(sut.faceMood, .happy)
        XCTAssertEqual(sut.speech, PlantMoodViewModel(mood: .happy).speech)
    }

    func test_faceMoodAndSpeech_areNilBeforeMoodLoads() {
        let sut = makeSUT(mood: nil)

        XCTAssertNil(sut.faceMood)
        XCTAssertNil(sut.speech)
    }

    // MARK: - Private helpers

    private func makeSUT(lux: Int? = 1_000, mood: PlantMood?) -> PlantMonitorSceneViewModel {
        PlantMonitorSceneViewModel(reading: makeReading(lux: lux), mood: mood)
    }

    private func makeSUT(reading: PlantReading?, mood: PlantMood?) -> PlantMonitorSceneViewModel {
        PlantMonitorSceneViewModel(reading: reading, mood: mood)
    }
}
