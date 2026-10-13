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

    func test_init_deliversSleepingAsMoodLabelWhileSleeping() {
        let sut = PlantMonitorHeaderViewModel(name: "Sprout", room: "Living room", mood: .happy, isSleeping: true)

        XCTAssertEqual(sut.subtitle, "Living room · Sleeping")
    }

    func test_init_deliversMoodWhenConnectedOrUnknown() {
        [nil, PlantConnection.connected].forEach { connection in
            let sut = PlantMonitorHeaderViewModel(name: "Sprout", room: "Living room", mood: .happy, connection: connection)

            XCTAssertEqual(sut.subtitle, "Living room · Happy", "\(String(describing: connection))")
        }
    }

    func test_init_deliversConnectionLabelInsteadOfMood() {
        let expected: [(PlantConnection, String)] = [
            (.notPaired, "No sensor paired"),
            (.connecting, "Connecting…"),
            (.offline, "Sensor offline"),
            (.bluetoothOff, "Bluetooth is off"),
            (.bluetoothUnauthorized, "Bluetooth not allowed"),
            (.bluetoothUnsupported, "Bluetooth isn't available on this device"),
            (.incompatible, "Sensor not compatible"),
        ]

        expected.forEach { connection, label in
            let sut = PlantMonitorHeaderViewModel(name: "Sprout", room: "Living room", mood: .happy, connection: connection)

            XCTAssertEqual(sut.subtitle, "Living room · \(label)", "\(connection)")
        }
    }

    func test_init_deliversConnectionLabelWithoutMood() {
        let sut = PlantMonitorHeaderViewModel(name: "Sprout", room: "Living room", mood: nil, connection: .connecting)

        XCTAssertEqual(sut.subtitle, "Living room · Connecting…")
    }

    func test_init_deliversConnectionLabelInsteadOfSleeping() {
        let sut = PlantMonitorHeaderViewModel(name: "Sprout", room: "Living room", mood: .happy, isSleeping: true, connection: .offline)

        XCTAssertEqual(sut.subtitle, "Living room · Sensor offline")
    }
}
