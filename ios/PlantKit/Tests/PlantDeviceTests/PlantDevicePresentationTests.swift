import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PlantDevicePresentationTests: PlantDeviceXCTestCase {
    func test_interval_formatsSecondsAndWholeMinutes() {
        XCTAssertEqual(PlantDeviceFormatter.interval(seconds: 30), "Every 30 s")
        XCTAssertEqual(PlantDeviceFormatter.interval(seconds: 59), "Every 59 s")
        XCTAssertEqual(PlantDeviceFormatter.interval(seconds: 60), "Every 1 min")
        XCTAssertEqual(PlantDeviceFormatter.interval(seconds: 300), "Every 5 min")
        XCTAssertEqual(PlantDeviceFormatter.interval(seconds: 90), "Every 90 s")
        XCTAssertEqual(PlantDeviceFormatter.interval(seconds: 3_600), "Every 60 min")
    }

    func test_infoViewModel_showsFirmwareAndInterval() {
        let sut = PlantDeviceInfoViewModel(info: anyDeviceInfo())

        XCTAssertEqual(sut.firmware, "0.1.0")
        XCTAssertEqual(sut.interval, "Every 30 s")
    }

    func test_connectionViewModel_labelsEveryConnection() {
        let labels: [(PlantConnection, String)] = [
            (.notPaired, "No sensor paired"),
            (.connecting, "Connecting…"),
            (.connected, "Connected"),
            (.offline, "Sensor offline"),
            (.bluetoothOff, "Bluetooth is off"),
            (.bluetoothUnauthorized, "Bluetooth not allowed"),
            (.bluetoothUnsupported, "Bluetooth isn't available on this device"),
            (.incompatible, "Sensor not compatible")
        ]

        labels.forEach { connection, label in
            XCTAssertEqual(PlantDeviceConnectionViewModel(connection: connection).label, label)
        }
    }

    func test_connectionViewModel_isConnectedOnlyWhenConnected() {
        XCTAssertTrue(PlantDeviceConnectionViewModel(connection: .connected).isConnected)
        XCTAssertFalse(PlantDeviceConnectionViewModel(connection: .connecting).isConnected)
        XCTAssertFalse(PlantDeviceConnectionViewModel(connection: .offline).isConnected)
    }

    func test_connectionViewModel_showsOpenSettingsOnlyWhenUnauthorized() {
        XCTAssertTrue(PlantDeviceConnectionViewModel(connection: .bluetoothUnauthorized).showsOpenSettings)
        XCTAssertFalse(PlantDeviceConnectionViewModel(connection: .bluetoothOff).showsOpenSettings)
        XCTAssertFalse(PlantDeviceConnectionViewModel(connection: .bluetoothUnsupported).showsOpenSettings)
    }

    func test_strings_haveValueForEveryKey() {
        let keys = [
            "plant.device.title",
            "plant.device.mode.section",
            "plant.device.mode.simulated.label",
            "plant.device.mode.sensor.label",
            "plant.device.sensor.section",
            "plant.device.status.label",
            "plant.device.paired.label",
            "plant.device.paired.none",
            "plant.device.firmware.label",
            "plant.device.interval.label",
            "plant.device.interval.seconds",
            "plant.device.interval.minutes",
            "plant.device.connection.notPaired.label",
            "plant.device.connection.connecting.label",
            "plant.device.connection.connected.label",
            "plant.device.connection.offline.label",
            "plant.device.connection.bluetoothOff.label",
            "plant.device.connection.bluetoothUnauthorized.label",
            "plant.device.connection.bluetoothUnsupported.label",
            "plant.device.connection.incompatible.label",
            "plant.device.readNow.label",
            "plant.device.pair.label",
            "plant.device.change.label",
            "plant.device.forget.label",
            "plant.device.openSettings.label",
            "plant.device.command.error"
        ]

        keys.forEach { key in
            XCTAssertNotEqual(String.localised(key: key), key, "Missing string for \(key)")
        }
    }
}
