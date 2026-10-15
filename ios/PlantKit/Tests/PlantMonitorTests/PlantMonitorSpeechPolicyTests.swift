import PlantShared
import XCTest
@testable import PlantMonitor

final class PlantMonitorSpeechPolicyTests: XCTestCase {
    func test_shouldSpeak_isTrueWhenNothingWasSpokenYet() {
        XCTAssertTrue(shouldSpeak(.happy, lastMood: nil, lastDay: nil))
    }

    func test_shouldSpeak_isFalseForSameMoodOnSameDay() {
        XCTAssertFalse(shouldSpeak(.happy, lastMood: .happy, lastDay: "2026-10-15"))
    }

    func test_shouldSpeak_isTrueForNewDay() {
        XCTAssertTrue(shouldSpeak(.happy, lastMood: .happy, lastDay: "2026-10-14"))
    }

    func test_shouldSpeak_isTrueForNewMoodOnSameDay() {
        XCTAssertTrue(shouldSpeak(.thirsty, lastMood: .happy, lastDay: "2026-10-15"))
    }

    func test_shouldSpeak_isFalseWhenOffline() {
        XCTAssertFalse(shouldSpeak(.offline, lastMood: nil, lastDay: nil))
        XCTAssertFalse(shouldSpeak(.offline, lastMood: .happy, lastDay: "2026-10-14"))
    }

    // MARK: - Helpers

    private func shouldSpeak(_ mood: PlantMood, lastMood: PlantMood?, lastDay: String?) -> Bool {
        PlantMonitorSpeechPolicy.shouldSpeak(mood: mood, lastMood: lastMood, lastDay: lastDay, today: "2026-10-15")
    }
}
