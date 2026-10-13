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

    func test_rawReadingViewModel_formatsEveryField() {
        let components = DateComponents(year: 2026, month: 10, day: 13, hour: 14, minute: 3, second: 15)
        let receivedAt = Calendar.current.date(from: components)!

        let sut = PlantDeviceRawReadingViewModel(reading: anyRawReading(sequence: 42, receivedAt: receivedAt))

        XCTAssertEqual(sut.soil, "2,431 mV")
        XCTAssertEqual(sut.light, "312 lx")
        XCTAssertEqual(sut.temperature, "23.41 °C")
        XCTAssertEqual(sut.humidity, "48.20 %")
        XCTAssertEqual(sut.flags, "0x07")
        XCTAssertEqual(sut.sequence, "#42")
        XCTAssertEqual(sut.received, "14:03:15")
    }

    func test_rawReadingViewModel_showsPlaceholderForMissingFields() {
        let reading = PlantDeviceRawReading(
            soilMillivolts: nil, lux: nil, temperature: nil, humidity: nil,
            flags: 0x00, sequence: 0, receivedAt: Date(timeIntervalSince1970: 0)
        )

        let sut = PlantDeviceRawReadingViewModel(reading: reading)

        XCTAssertEqual([sut.soil, sut.light, sut.temperature, sut.humidity], ["–", "–", "–", "–"])
        XCTAssertEqual(sut.flags, "0x00")
    }

    func test_rawReadingViewModel_formatsFlagsAsTwoHexDigits() {
        XCTAssertEqual(PlantDeviceRawReadingViewModel(reading: anyRawReading(flags: 0x0A)).flags, "0x0A")
    }

    func test_calibrationStatusViewModel_describesCalibration() {
        let calibrated = PlantDeviceCalibrationStatusViewModel(calibration: MoistureCalibration(dryMillivolts: 2_447, wetMillivolts: 1_062)!)
        let placeholder = PlantDeviceCalibrationStatusViewModel(calibration: .placeholder)

        XCTAssertEqual(calibrated.status, "Calibrated")
        XCTAssertEqual(calibrated.dry, "2,447 mV")
        XCTAssertEqual(calibrated.wet, "1,062 mV")
        XCTAssertTrue(calibrated.isCalibrated)
        XCTAssertEqual(placeholder.status, "Not calibrated")
        XCTAssertEqual(placeholder.dry, "2,450 mV")
        XCTAssertEqual(placeholder.wet, "1,050 mV")
        XCTAssertFalse(placeholder.isCalibrated)
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
            "plant.device.command.error",
            "plant.device.calibration.title",
            "plant.device.calibration.status.label",
            "plant.device.calibration.status.calibrated",
            "plant.device.calibration.status.notCalibrated",
            "plant.device.calibration.dry.label",
            "plant.device.calibration.wet.label",
            "plant.device.calibration.now.section",
            "plant.device.calibration.soil.label",
            "plant.device.calibration.dry.section",
            "plant.device.calibration.dry.capture",
            "plant.device.calibration.dry.hint",
            "plant.device.calibration.wet.section",
            "plant.device.calibration.wet.capture",
            "plant.device.calibration.wet.hint",
            "plant.device.calibration.save",
            "plant.device.calibration.reset",
            "plant.device.calibration.offline",
            "plant.device.calibration.error.soil",
            "plant.device.calibration.error.timeout",
            "plant.device.calibration.error.missingDry",
            "plant.device.calibration.error.missingWet",
            "plant.device.calibration.error.wetNotBelowDry",
            "plant.device.calibration.error.rangeTooSmall",
            "plant.device.calibration.warning.nearLimit",
            "plant.device.raw.section",
            "plant.device.raw.soil.label",
            "plant.device.raw.light.label",
            "plant.device.raw.temperature.label",
            "plant.device.raw.humidity.label",
            "plant.device.raw.flags.label",
            "plant.device.raw.sequence.label",
            "plant.device.raw.received.label"
        ]

        keys.forEach { key in
            XCTAssertNotEqual(String.localised(key: key), key, "Missing string for \(key)")
        }
    }
}
