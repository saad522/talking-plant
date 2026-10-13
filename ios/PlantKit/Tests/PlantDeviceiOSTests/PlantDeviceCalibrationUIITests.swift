import PlantDevice
import PlantShared
import XCTest

@MainActor
final class PlantDeviceCalibrationUIITests: PlantDeviceiOSXCTestCase {
    private let notCalibrated = String.localised(key: "plant.device.calibration.status.notCalibrated")
    private let calibrated = String.localised(key: "plant.device.calibration.status.calibrated")
    private let captureDry = String.localised(key: "plant.device.calibration.dry.capture")
    private let captureWet = String.localised(key: "plant.device.calibration.wet.capture")
    private let save = String.localised(key: "plant.device.calibration.save")
    private let reset = String.localised(key: "plant.device.calibration.reset")

    // MARK: Settings rows

    func test_settings_showsCalibrationRowWithStatusAndSendsAction() {
        var actions: [PlantDeviceAction] = []
        let (sut, _, _, _, _, _) = makeSUT(savedMode: .sensor, actionHandler: { actions.append($0) })
        let title = String.localised(key: "plant.device.calibration.title")

        sut.simulateAppear()

        XCTAssertTrue(sut.texts.contains(title))
        XCTAssertTrue(sut.texts.contains(notCalibrated))

        sut.simulateTapRow(title)

        XCTAssertEqual(actions, [.calibrationTap])
    }

    func test_settings_calibrationRowShowsCalibratedWhenSaved() {
        let (sut, _, _, _, _, defaults) = makeSUT(savedMode: .sensor)
        LocalMoistureCalibrationLoader(defaults: defaults).save(MoistureCalibration(dryMillivolts: 2_300, wetMillivolts: 1_000)!)

        sut.simulateAppear()

        XCTAssertTrue(sut.texts.contains(calibrated))
    }

    func test_settings_rawSectionIsHiddenByDefault() {
        let (sut, connection, raw) = makeRawSUT(showsRawReading: false)

        sut.simulateAppear()
        connection.simulate(.connected)
        raw.completeLoad(with: anyRawReading())

        XCTAssertFalse(sut.texts.contains(String.localised(key: "plant.device.raw.section")))
        XCTAssertFalse(sut.texts.contains("2,431 mV"))
    }

    func test_settings_rawSectionShownWithFlagAndFilledOnReading() {
        let (sut, connection, raw) = makeRawSUT(showsRawReading: true)

        sut.simulateAppear()
        connection.simulate(.connected)

        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.raw.section")))
        XCTAssertFalse(sut.texts.contains("2,431 mV"))

        raw.completeLoad(with: anyRawReading(sequence: 42))

        XCTAssertTrue(sut.texts.contains("2,431 mV"))
        XCTAssertTrue(sut.texts.contains("312 lx"))
        XCTAssertTrue(sut.texts.contains("23.41 °C"))
        XCTAssertTrue(sut.texts.contains("48.20 %"))
        XCTAssertTrue(sut.texts.contains("0x07"))
        XCTAssertTrue(sut.texts.contains("#42"))

        raw.simulate(anyRawReading(soilMillivolts: 1_050, sequence: 43))

        XCTAssertTrue(sut.texts.contains("1,050 mV"))
        XCTAssertTrue(sut.texts.contains("#43"))
    }

    // MARK: Calibration screen

    func test_calibration_showsStatusAndDefaultsWhenNotCalibrated() {
        let (sut, _, _, _, _) = makeCalibrationSUT()

        sut.simulateAppear()

        XCTAssertTrue(sut.texts.contains(notCalibrated))
        XCTAssertTrue(sut.texts.contains("2,450 mV"))
        XCTAssertTrue(sut.texts.contains("1,050 mV"))
        XCTAssertFalse(sut.hasButton(reset))
    }

    func test_calibration_showsSavedValuesAndResetWhenCalibrated() {
        let (sut, _, _, _, _) = makeCalibrationSUT(savedCalibration: MoistureCalibration(dryMillivolts: 2_300, wetMillivolts: 1_000)!)

        sut.simulateAppear()

        XCTAssertTrue(sut.texts.contains(calibrated))
        XCTAssertTrue(sut.texts.contains("2,300 mV"))
        XCTAssertTrue(sut.texts.contains("1,000 mV"))
        XCTAssertTrue(sut.hasButton(reset))
    }

    func test_calibration_resetReturnsToDefaults() {
        let (sut, _, _, _, _) = makeCalibrationSUT(savedCalibration: MoistureCalibration(dryMillivolts: 2_300, wetMillivolts: 1_000)!)

        sut.simulateAppear()
        sut.simulateTap(reset)

        XCTAssertTrue(sut.texts.contains(notCalibrated))
        XCTAssertTrue(sut.texts.contains("2,450 mV"))
        XCTAssertFalse(sut.hasButton(reset))
    }

    func test_calibration_captureButtonsAreDisabledWhenOffline() {
        let (sut, connection, _, _, _) = makeCalibrationSUT()

        sut.simulateAppear()

        XCTAssertTrue(sut.isButtonDisabled(captureDry))
        XCTAssertTrue(sut.isButtonDisabled(captureWet))
        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.calibration.offline")))

        connection.simulate(.connected)

        XCTAssertFalse(sut.isButtonDisabled(captureDry))
        XCTAssertFalse(sut.isButtonDisabled(captureWet))
        XCTAssertFalse(sut.texts.contains(String.localised(key: "plant.device.calibration.offline")))
    }

    func test_calibration_showsLiveSoil() {
        let (sut, connection, raw, _, _) = makeCalibrationSUT()

        sut.simulateAppear()
        connection.simulate(.connected)
        raw.simulate(anyRawReading(soilMillivolts: 2_431))

        XCTAssertTrue(sut.texts.contains("2,431 mV"))
    }

    func test_calibration_captureShowsSpinnerThenValue() {
        let (sut, connection, raw, commands, _) = makeCalibrationSUT()

        sut.simulateAppear()
        connection.simulate(.connected)
        raw.simulate(anyRawReading(soilMillivolts: 2_000, sequence: 1))
        sut.simulateTap(captureDry)

        XCTAssertEqual(commands.commands, [.readNow])
        XCTAssertTrue(sut.hasSpinner)

        raw.simulate(anyRawReading(soilMillivolts: 2_447, sequence: 2))

        XCTAssertFalse(sut.hasSpinner)
        XCTAssertTrue(sut.texts.contains("2,447 mV"))
    }

    func test_calibration_saveIsDisabledUntilBothPointsAreCaptured() {
        let (sut, connection, raw, _, _) = makeCalibrationSUT()

        sut.simulateAppear()
        connection.simulate(.connected)
        XCTAssertTrue(sut.isButtonDisabled(save))

        sut.simulateTap(captureDry)
        raw.simulate(anyRawReading(soilMillivolts: 2_447, sequence: 1))
        XCTAssertTrue(sut.isButtonDisabled(save))

        sut.simulateTap(captureWet)
        raw.simulate(anyRawReading(soilMillivolts: 1_062, sequence: 2))
        XCTAssertFalse(sut.isButtonDisabled(save))
    }

    func test_calibration_saveStoresValuesAndShowsCalibrated() {
        let (sut, connection, raw, commands, _) = makeCalibrationSUT()

        sut.simulateAppear()
        connection.simulate(.connected)
        sut.simulateTap(captureDry)
        raw.simulate(anyRawReading(soilMillivolts: 2_447, sequence: 1))
        sut.simulateTap(captureWet)
        raw.simulate(anyRawReading(soilMillivolts: 1_062, sequence: 2))
        sut.simulateTap(save)

        XCTAssertTrue(sut.texts.contains(calibrated))
        XCTAssertTrue(sut.texts.contains("2,447 mV"))
        XCTAssertTrue(sut.texts.contains("1,062 mV"))
        XCTAssertTrue(sut.isButtonDisabled(save))
        XCTAssertTrue(sut.hasButton(reset))
        XCTAssertEqual(commands.commands, [.readNow, .readNow, .readNow])
    }

    func test_calibration_showsErrorsAndWarning() {
        let (sut, connection, raw, commands, schedule) = makeCalibrationSUT()

        sut.simulateAppear()
        connection.simulate(.connected)

        sut.simulateTap(captureDry)
        commands.completeSend(with: anyNSError())
        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.command.error")))

        sut.simulateTap(captureDry)
        schedule.fire(at: 1)
        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.calibration.error.timeout")))

        sut.simulateTap(captureDry)
        raw.simulate(anyRawReading(soilMillivolts: 2_490, sequence: 1))
        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.calibration.warning.nearLimit")))

        sut.simulateTap(captureWet)
        raw.simulate(anyRawReading(soilMillivolts: 2_300, sequence: 2))
        sut.simulateTap(save)
        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.calibration.error.rangeTooSmall")))
    }
}
