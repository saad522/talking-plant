import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PlantDeviceCalibrationViewModelTests: PlantDeviceXCTestCase {
    func test_init_doesNotMessageCollaborators() {
        let (_, raw, connection, commands, schedule, defaults) = makeSUT()

        XCTAssertEqual(raw.subscriptionCount, 0)
        XCTAssertEqual(raw.loadCount, 0)
        XCTAssertEqual(connection.subscriptionCount, 0)
        XCTAssertEqual(commands.commands, [])
        XCTAssertEqual(schedule.intervals, [])
        XCTAssertEqual(defaults.messages, [])
    }

    func test_appear_deliversSavedStatusAndSubscribesOnce() {
        let (sut, raw, connection, _, _, defaults) = makeSUT()
        defaults.stub(2_400.0, forKey: LocalMoistureCalibrationLoader.dryKey)
        defaults.stub(1_100.0, forKey: LocalMoistureCalibrationLoader.wetKey)
        var statuses: [PlantDeviceCalibrationStatusViewModel] = []
        sut.loadedStatus = { statuses.append($0) }

        sut.appear()
        sut.appear()

        XCTAssertEqual(statuses.map(\.dry), ["2,400 mV", "2,400 mV"])
        XCTAssertEqual(statuses.map(\.status), ["Calibrated", "Calibrated"])
        XCTAssertEqual(raw.subscriptionCount, 1)
        XCTAssertEqual(connection.subscriptionCount, 1)
    }

    func test_appear_deliversPlaceholderStatusWhenNothingSaved() {
        let (sut, _, _, _, _, _) = makeSUT()
        var statuses: [PlantDeviceCalibrationStatusViewModel] = []
        sut.loadedStatus = { statuses.append($0) }

        sut.appear()

        XCTAssertEqual(statuses.map(\.status), ["Not calibrated"])
        XCTAssertEqual(statuses.map(\.dry), ["2,450 mV"])
        XCTAssertEqual(statuses.map(\.wet), ["1,050 mV"])
    }

    func test_connection_deliversCanCaptureAndLoadsRawReadingOnTransitionIntoConnected() {
        let (sut, raw, connection, _, _, _) = makeSUT()
        var canCapture: [Bool] = []
        sut.loadedCanCapture = { canCapture.append($0) }
        sut.appear()

        connection.simulate(.connecting)
        connection.simulate(.connected)
        connection.simulate(.connected)
        connection.simulate(.offline)

        XCTAssertEqual(canCapture, [false, true, true, false])
        XCTAssertEqual(raw.loadCount, 1)
    }

    func test_rawReading_deliversLiveSoil() {
        let (sut, raw, _, _, _, _) = makeSUT()
        var soil: [String] = []
        sut.loadedLiveSoil = { soil.append($0) }
        sut.appear()

        raw.simulate(anyRawReading(soilMillivolts: 2_431, sequence: 1))
        raw.simulate(anyRawReading(soilMillivolts: nil, sequence: 2, flags: 0x06))
        raw.simulate(error: anyNSError())

        XCTAssertEqual(soil, ["2,431 mV", "–"])
    }

    func test_captureTap_doesNothingWhenNotConnected() {
        let (sut, _, _, commands, schedule, _) = makeSUT()
        sut.appear()

        sut.captureTap(.dry)

        XCTAssertEqual(commands.commands, [])
        XCTAssertEqual(schedule.intervals, [])
    }

    func test_captureTap_sendsReadNowSchedulesTimeoutAndShowsCapturing() {
        let (sut, _, connection, commands, schedule, _) = makeSUT()
        var capturing: [PlantDeviceCalibrationPoint?] = []
        sut.loadedCapturing = { capturing.append($0) }
        sut.appear()
        connection.simulate(.connected)

        sut.captureTap(.dry)

        XCTAssertEqual(commands.commands, [.readNow])
        XCTAssertEqual(schedule.intervals, [10])
        XCTAssertEqual(capturing, [.dry])
    }

    func test_capture_takesNextReadingWithNewSequence() {
        let (sut, raw, connection, _, _, _) = makeSUT()
        var drafts: [(PlantDeviceCalibrationPoint, String?)] = []
        var capturing: [PlantDeviceCalibrationPoint?] = []
        sut.loadedDraft = { drafts.append(($0.point, $0.text)) }
        sut.loadedCapturing = { capturing.append($0) }
        sut.appear()
        connection.simulate(.connected)
        raw.simulate(anyRawReading(soilMillivolts: 1_000, sequence: 5))

        sut.captureTap(.dry)
        raw.simulate(anyRawReading(soilMillivolts: 1_000, sequence: 5))
        XCTAssertEqual(drafts.count, 0, "Same sequence is ignored")

        raw.simulate(anyRawReading(soilMillivolts: 2_447, sequence: 6))

        XCTAssertEqual(drafts.map(\.0), [.dry])
        XCTAssertEqual(drafts.map(\.1), ["2,447 mV"])
        XCTAssertEqual(capturing, [.dry, nil])
    }

    func test_capture_takesFirstReadingWhenNoneWasSeenBefore() {
        let (sut, raw, connection, _, _, _) = makeSUT()
        var drafts: [String?] = []
        sut.loadedDraft = { drafts.append($0.text) }
        sut.appear()
        connection.simulate(.connected)

        sut.captureTap(.wet)
        raw.simulate(anyRawReading(soilMillivolts: 1_062, sequence: 0))

        XCTAssertEqual(drafts, ["1,062 mV"])
    }

    func test_capture_deliversMessageWhenSoilFlagIsClear() {
        let (sut, raw, connection, _, _, _) = makeSUT()
        var messages: [String?] = []
        var drafts: [String?] = []
        sut.loadedMessage = { messages.append($0) }
        sut.loadedDraft = { drafts.append($0.text) }
        sut.appear()
        connection.simulate(.connected)

        sut.captureTap(.dry)
        raw.simulate(anyRawReading(soilMillivolts: nil, sequence: 1, flags: 0x06))

        XCTAssertEqual(messages, [nil, "The soil sensor isn't reading."])
        XCTAssertEqual(drafts, [])
    }

    func test_capture_deliversMessageOnWriteError() {
        let (sut, _, connection, commands, _, _) = makeSUT()
        var messages: [String?] = []
        var capturing: [PlantDeviceCalibrationPoint?] = []
        sut.loadedMessage = { messages.append($0) }
        sut.loadedCapturing = { capturing.append($0) }
        sut.appear()
        connection.simulate(.connected)

        sut.captureTap(.dry)
        commands.completeSend(with: anyNSError())

        XCTAssertEqual(messages, [nil, "Couldn't reach the sensor."])
        XCTAssertEqual(capturing, [.dry, nil])
    }

    func test_capture_deliversMessageOnTimeoutAndIgnoresLateReading() {
        let (sut, raw, connection, _, schedule, _) = makeSUT()
        var messages: [String?] = []
        var drafts: [String?] = []
        sut.loadedMessage = { messages.append($0) }
        sut.loadedDraft = { drafts.append($0.text) }
        sut.appear()
        connection.simulate(.connected)

        sut.captureTap(.dry)
        let repeats = schedule.fire()
        raw.simulate(anyRawReading(soilMillivolts: 2_447, sequence: 1))

        XCTAssertFalse(repeats)
        XCTAssertEqual(messages, [nil, "No reading from the sensor. Try again."])
        XCTAssertEqual(drafts, [])
    }

    func test_capture_staleTimeoutDoesNotCancelLaterCapture() {
        let (sut, raw, connection, _, schedule, _) = makeSUT()
        var messages: [String?] = []
        sut.loadedMessage = { messages.append($0) }
        sut.appear()
        connection.simulate(.connected)

        sut.captureTap(.dry)
        raw.simulate(anyRawReading(soilMillivolts: 2_447, sequence: 1))
        sut.captureTap(.dry)
        schedule.fire(at: 0)

        XCTAssertEqual(messages, [nil, nil, nil])
    }

    func test_recapture_replacesDraft() {
        let (sut, raw, connection, _, _, _) = makeSUT()
        var drafts: [String?] = []
        sut.loadedDraft = { drafts.append($0.text) }
        sut.appear()
        connection.simulate(.connected)

        sut.captureTap(.dry)
        raw.simulate(anyRawReading(soilMillivolts: 2_447, sequence: 1))
        sut.captureTap(.dry)
        raw.simulate(anyRawReading(soilMillivolts: 2_440, sequence: 2))

        XCTAssertEqual(drafts, ["2,447 mV", "2,440 mV"])
    }

    func test_canSave_isTrueOnlyWhenBothPointsAreCaptured() {
        let (sut, raw, connection, _, _, _) = makeSUT()
        var canSave: [Bool] = []
        sut.loadedCanSave = { canSave.append($0) }
        sut.appear()
        connection.simulate(.connected)

        capture(.dry, soil: 2_447, sequence: 1, sut, raw)
        capture(.wet, soil: 1_062, sequence: 2, sut, raw)

        XCTAssertEqual(canSave, [false, true])
    }

    func test_capture_warnsWhenDryIsNearTheADCLimit() {
        let (sut, raw, connection, _, _, _) = makeSUT()
        var warnings: [String?] = []
        sut.loadedWarning = { warnings.append($0) }
        sut.appear()
        connection.simulate(.connected)

        capture(.dry, soil: 2_480, sequence: 1, sut, raw)
        capture(.dry, soil: 2_479, sequence: 2, sut, raw)

        XCTAssertEqual(warnings, [
            "Dry is near the top of the board's range. Check the sensor is on 3V3, not 5V.",
            nil
        ])
    }

    func test_saveTap_savesCalibrationClearsDraftsAndSendsReadNow() {
        let (sut, raw, connection, commands, _, defaults) = makeSUT()
        var statuses: [PlantDeviceCalibrationStatusViewModel] = []
        var drafts: [(PlantDeviceCalibrationPoint, String?)] = []
        var canSave: [Bool] = []
        sut.loadedStatus = { statuses.append($0) }
        sut.loadedDraft = { drafts.append(($0.point, $0.text)) }
        sut.loadedCanSave = { canSave.append($0) }
        sut.appear()
        connection.simulate(.connected)
        capture(.dry, soil: 2_447, sequence: 1, sut, raw)
        capture(.wet, soil: 1_062, sequence: 2, sut, raw)
        commands.completeSend(with: nil, at: 0)
        commands.completeSend(with: nil, at: 1)
        statuses.removeAll()
        drafts.removeAll()

        sut.saveTap()

        XCTAssertTrue(defaults.messages.contains(.setDouble(2_447, forKey: LocalMoistureCalibrationLoader.dryKey)))
        XCTAssertTrue(defaults.messages.contains(.setDouble(1_062, forKey: LocalMoistureCalibrationLoader.wetKey)))
        XCTAssertEqual(statuses.map(\.status), ["Calibrated"])
        XCTAssertEqual(drafts.map(\.0), [.dry, .wet])
        XCTAssertEqual(drafts.map(\.1), [nil, nil])
        XCTAssertEqual(canSave.last, false)
        XCTAssertEqual(commands.commands, [.readNow, .readNow, .readNow])
    }

    func test_saveTap_deliversLoadedSavedOnceAfterValidSave() {
        let (sut, raw, connection, _, _, _) = makeSUT()
        var saved = 0
        sut.loadedSaved = { _ in saved += 1 }
        sut.appear()
        connection.simulate(.connected)
        capture(.dry, soil: 2_447, sequence: 1, sut, raw)
        capture(.wet, soil: 1_062, sequence: 2, sut, raw)

        sut.saveTap()

        XCTAssertEqual(saved, 1)
    }

    func test_saveTap_doesNotDeliverLoadedSavedOnValidationError() {
        let (sut, raw, connection, _, _, _) = makeSUT()
        var saved = 0
        sut.loadedSaved = { _ in saved += 1 }
        sut.appear()
        connection.simulate(.connected)
        capture(.dry, soil: 1_000, sequence: 1, sut, raw)
        capture(.wet, soil: 1_500, sequence: 2, sut, raw)

        sut.saveTap()
        sut.saveTap()

        XCTAssertEqual(saved, 0)
    }

    func test_resetTap_doesNotDeliverLoadedSaved() {
        let (sut, _, _, _, _, _) = makeSUT()
        var saved = 0
        sut.loadedSaved = { _ in saved += 1 }
        sut.appear()

        sut.resetTap()

        XCTAssertEqual(saved, 0)
    }

    func test_saveTap_deliversMessageForEachValidationError() {
        let cases: [(dry: Int?, wet: Int?, message: String)] = [
            (nil, nil, "Capture the dry point first."),
            (2_447, nil, "Capture the wet point first."),
            (1_000, 1_500, "The wet reading must be lower than the dry one. Capture both again."),
            (1_500, 1_500, "The wet reading must be lower than the dry one. Capture both again."),
            (2_000, 1_701, "Dry and wet are too close together. Check the sensor is in air, then in water.")
        ]

        for testCase in cases {
            let (sut, raw, connection, commands, _, defaults) = makeSUT()
            var messages: [String?] = []
            sut.appear()
            connection.simulate(.connected)
            if let dry = testCase.dry { capture(.dry, soil: dry, sequence: 1, sut, raw) }
            if let wet = testCase.wet { capture(.wet, soil: wet, sequence: 2, sut, raw) }
            sut.loadedMessage = { messages.append($0) }
            let writesBefore = defaults.messages.count
            let commandsBefore = commands.commands.count

            sut.saveTap()

            XCTAssertEqual(messages, [testCase.message])
            XCTAssertEqual(defaults.messages.count, writesBefore, "Nothing is saved on a validation error")
            XCTAssertEqual(commands.commands.count, commandsBefore)
        }
    }

    func test_resetTap_resetsCalibrationAndClearsDrafts() {
        let (sut, raw, connection, _, _, defaults) = makeSUT()
        defaults.stub(2_400.0, forKey: LocalMoistureCalibrationLoader.dryKey)
        defaults.stub(1_100.0, forKey: LocalMoistureCalibrationLoader.wetKey)
        var statuses: [PlantDeviceCalibrationStatusViewModel] = []
        var drafts: [String?] = []
        sut.loadedStatus = { statuses.append($0) }
        sut.loadedDraft = { drafts.append($0.text) }
        sut.appear()
        connection.simulate(.connected)
        capture(.dry, soil: 2_447, sequence: 1, sut, raw)
        statuses.removeAll()
        drafts.removeAll()

        sut.resetTap()

        XCTAssertTrue(defaults.messages.contains(.setDouble(0, forKey: LocalMoistureCalibrationLoader.dryKey)))
        XCTAssertTrue(defaults.messages.contains(.setDouble(0, forKey: LocalMoistureCalibrationLoader.wetKey)))
        XCTAssertEqual(statuses.map(\.status), ["Not calibrated"])
        XCTAssertEqual(drafts, [nil, nil])
    }

    func test_appear_doesNotCreateMemoryLeaks() {
        let raw = RawReadingLoaderStub()
        let connection = ConnectionLoaderStub()
        let commands = CommandSenderStub()
        let schedule = ScheduleSpy()
        var sut: PlantDeviceCalibrationViewModel? = PlantDeviceCalibrationViewModel(
            calibrationLoader: LocalMoistureCalibrationLoader(defaults: DefaultsSpy()),
            rawReadingLoader: raw,
            connectionLoader: connection,
            commandSender: commands,
            schedule: schedule.schedule
        )
        weak var weakSUT = sut

        sut?.appear()
        connection.simulate(.connected)
        sut?.captureTap(.dry)
        raw.simulate(anyRawReading(sequence: 1))
        sut?.saveTap()

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func capture(
        _ point: PlantDeviceCalibrationPoint,
        soil: Int,
        sequence: UInt32,
        _ sut: PlantDeviceCalibrationViewModel,
        _ raw: RawReadingLoaderStub
    ) {
        sut.captureTap(point)
        raw.simulate(anyRawReading(soilMillivolts: soil, sequence: sequence))
    }

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: PlantDeviceCalibrationViewModel,
        raw: RawReadingLoaderStub,
        connection: ConnectionLoaderStub,
        commands: CommandSenderStub,
        schedule: ScheduleSpy,
        defaults: DefaultsSpy
    ) {
        let raw = RawReadingLoaderStub()
        let connection = ConnectionLoaderStub()
        let commands = CommandSenderStub()
        let schedule = ScheduleSpy()
        let defaults = DefaultsSpy()
        let sut = PlantDeviceCalibrationViewModel(
            calibrationLoader: LocalMoistureCalibrationLoader(defaults: defaults),
            rawReadingLoader: raw,
            connectionLoader: connection,
            commandSender: commands,
            schedule: schedule.schedule
        )
        trackMemoryLeak(raw, file: file, line: line)
        trackMemoryLeak(connection, file: file, line: line)
        trackMemoryLeak(commands, file: file, line: line)
        trackMemoryLeak(schedule, file: file, line: line)
        trackMemoryLeak(defaults, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, raw, connection, commands, schedule, defaults)
    }
}
