import PlantShared
import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorHeaderViewModelTests: PlantMonitorXCTestCase {
    func test_init_deliversNameAsTitle() {
        let sut = PlantMonitorHeaderViewModel(name: "Sprout", room: "Living room", mood: nil)

        XCTAssertEqual(sut.title, "Sprout")
    }

    func test_init_deliversOnlyRoomAsSubtitleBeforeMoodLoads() {
        let sut = PlantMonitorHeaderViewModel(name: "Sprout", room: "Living room", mood: nil)

        XCTAssertEqual(sut.subtitle, "Living room")
    }

    func test_init_deliversRoomAndMoodLabelAsSubtitle() {
        let sut = PlantMonitorHeaderViewModel(name: "Sprout", room: "Living room", mood: .veryThirsty)

        XCTAssertEqual(sut.subtitle, "Living room · Very thirsty")
    }
}
