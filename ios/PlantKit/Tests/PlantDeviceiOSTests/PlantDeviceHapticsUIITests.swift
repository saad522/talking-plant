import PlantDevice
import PlantShared
import XCTest

@MainActor
final class PlantDeviceHapticsUIITests: PlantDeviceiOSXCTestCase {
    // MARK: Settings

    func test_settings_appearAndConnectionUpdates_playNoHaptic() {
        let haptics = HapticsSpy()
        let (sut, connection, pairing, info, _, _) = makeSUT(savedMode: .sensor, haptics: haptics)

        sut.simulateAppear()
        connection.simulate(.connected)
        pairing.simulate(anyPairedDevice())
        info.completeLoad(with: anyDeviceInfo())

        XCTAssertEqual(haptics.played, [])
    }

    func test_settings_modeSelect_playsSelectionAndStillSendsAction() {
        var actions: [PlantDeviceAction] = []
        let haptics = HapticsSpy()
        let (sut, _, _, _, _, _) = makeSUT(haptics: haptics, actionHandler: { actions.append($0) })
        sut.simulateAppear()

        sut.simulateSelectMode(.sensor)

        XCTAssertEqual(haptics.played, [.selection])
        XCTAssertEqual(actions, [.modeChanged(.sensor)])
    }

    func test_settings_buttons_playOneTapEach() {
        let cases: [(name: String, connection: PlantConnection, paired: Bool, label: String, row: Bool)] = [
            ("open settings", .bluetoothUnauthorized, false, String.localised(key: "plant.device.openSettings.label"), false),
            ("read now", .connected, false, String.localised(key: "plant.device.readNow.label"), false),
            ("calibration", .connecting, false, String.localised(key: "plant.device.calibration.title"), true),
            ("pair", .connecting, false, String.localised(key: "plant.device.pair.label"), false),
            ("change", .connecting, true, String.localised(key: "plant.device.change.label"), false),
            ("forget", .connecting, true, String.localised(key: "plant.device.forget.label"), false)
        ]

        for testCase in cases {
            let haptics = HapticsSpy()
            let (sut, connection, pairing, _, _, _) = makeSUT(savedMode: .sensor, haptics: haptics)
            sut.simulateAppear()
            connection.simulate(testCase.connection)
            if testCase.paired { pairing.simulate(anyPairedDevice()) }

            if testCase.row {
                sut.simulateTapRow(testCase.label)
            } else {
                sut.simulateTap(testCase.label)
            }

            XCTAssertEqual(haptics.played, [.tap], testCase.name)
        }
    }

    func test_settings_clearHistoryButton_playsTap() {
        let haptics = HapticsSpy()
        let (sut, _, _) = makeRawSUT(showsRawReading: true, haptics: haptics)
        sut.simulateAppear()

        sut.simulateTap(String.localised(key: "plant.device.clearHistory.label"))

        XCTAssertEqual(haptics.played, [.tap])
    }

    // MARK: Calibration

    func test_calibration_captureAndReset_playOneTapEach() {
        let haptics = HapticsSpy()
        let saved = MoistureCalibration(dryMillivolts: 2_300, wetMillivolts: 1_000)
        let (sut, connection, raw, _, _) = makeCalibrationSUT(savedCalibration: saved, haptics: haptics)
        sut.simulateAppear()
        connection.simulate(.connected)
        XCTAssertEqual(haptics.played, [])

        sut.simulateTap(String.localised(key: "plant.device.calibration.dry.capture"))
        raw.simulate(anyRawReading(soilMillivolts: 2_447, sequence: 1))
        XCTAssertEqual(haptics.played, [.tap])

        sut.simulateTap(String.localised(key: "plant.device.calibration.wet.capture"))
        raw.simulate(anyRawReading(soilMillivolts: 1_062, sequence: 2))
        XCTAssertEqual(haptics.played, [.tap, .tap])

        sut.simulateTap(String.localised(key: "plant.device.calibration.reset"))
        XCTAssertEqual(haptics.played, [.tap, .tap, .tap])
    }

    func test_calibration_save_playsOnlySuccessNeverATapToo() {
        let haptics = HapticsSpy()
        let (sut, connection, raw, _, _) = makeCalibrationSUT(haptics: haptics)
        sut.simulateAppear()
        connection.simulate(.connected)
        sut.simulateTap(String.localised(key: "plant.device.calibration.dry.capture"))
        raw.simulate(anyRawReading(soilMillivolts: 2_447, sequence: 1))
        sut.simulateTap(String.localised(key: "plant.device.calibration.wet.capture"))
        raw.simulate(anyRawReading(soilMillivolts: 1_062, sequence: 2))
        haptics.clear()

        sut.simulateTap(String.localised(key: "plant.device.calibration.save"))

        XCTAssertEqual(haptics.played, [.success])
    }

    func test_calibration_save_playsChime() {
        let sounds = SoundEffectsSpy()
        let (sut, connection, raw, _, _) = makeCalibrationSUT(sounds: sounds)
        sut.simulateAppear()
        connection.simulate(.connected)
        sut.simulateTap(String.localised(key: "plant.device.calibration.dry.capture"))
        raw.simulate(anyRawReading(soilMillivolts: 2_447, sequence: 1))
        sut.simulateTap(String.localised(key: "plant.device.calibration.wet.capture"))
        raw.simulate(anyRawReading(soilMillivolts: 1_062, sequence: 2))
        XCTAssertEqual(sounds.played, [])

        sut.simulateTap(String.localised(key: "plant.device.calibration.save"))

        XCTAssertEqual(sounds.played, [.chime])
    }

    func test_calibration_invalidSaveAndReset_playNoSound() {
        let sounds = SoundEffectsSpy()
        let (sut, _, _, _, _) = makeCalibrationSUT(sounds: sounds)
        sut.simulateAppear()

        sut.simulateTap(String.localised(key: "plant.device.calibration.save"))
        sut.simulateTap(String.localised(key: "plant.device.calibration.reset"))

        XCTAssertEqual(sounds.played, [])
    }
}
