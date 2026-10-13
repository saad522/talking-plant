import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PlantDeviceViewModelTests: PlantDeviceXCTestCase {
    func test_init_doesNotMessageCollaborators() {
        let (_, connection, pairing, info, commands, defaults) = makeSUT()

        XCTAssertEqual(connection.subscriptionCount, 0)
        XCTAssertEqual(pairing.messages, [])
        XCTAssertEqual(info.loadCount, 0)
        XCTAssertEqual(commands.commands, [])
        XCTAssertEqual(defaults.messages, [])
    }

    func test_appear_subscribesOnce() {
        let (sut, connection, pairing, _, _, _) = makeSUT()

        sut.appear()
        sut.appear()

        XCTAssertEqual(connection.subscriptionCount, 1)
        XCTAssertEqual(pairing.messages, [.subscribe])
    }

    func test_appear_deliversSavedMode() {
        let (sut, _, _, _, _, defaults) = makeSUT()
        defaults.stub("sensor", forKey: PlantDeviceSettings.modeKey)
        var modes: [PlantDeviceMode] = []
        sut.loadedMode = { modes.append($0) }

        sut.appear()

        XCTAssertEqual(modes, [.sensor])
    }

    func test_appear_deliversSimulatedModeByDefault() {
        let (sut, _, _, _, _, _) = makeSUT()
        var modes: [PlantDeviceMode] = []
        sut.loadedMode = { modes.append($0) }

        sut.appear()

        XCTAssertEqual(modes, [.simulated])
    }

    func test_connection_deliversConnectionViewModel() {
        let (sut, connection, _, _, _, _) = makeSUT()
        var labels: [String] = []
        sut.loadedConnection = { labels.append($0.label) }

        sut.appear()
        connection.simulate(.connecting)
        connection.simulate(.offline)

        XCTAssertEqual(labels, [
            String.localised(key: "plant.device.connection.connecting.label"),
            String.localised(key: "plant.device.connection.offline.label")
        ])
    }

    func test_pairedDevice_deliversPairedDevice() {
        let (sut, _, pairing, _, _, _) = makeSUT()
        let device = PlantPairedDevice(identifier: anyIdentifier(), name: "TalkingPlant-TEST")
        var received: [PlantPairedDevice?] = []
        sut.loadedPairedDevice = { received.append($0) }

        sut.appear()
        pairing.simulate(device)
        pairing.simulate(nil)

        XCTAssertEqual(received, [device, nil])
    }

    func test_connection_loadsInfoOnEachTransitionIntoConnected() {
        let (sut, connection, _, info, _, _) = makeSUT()
        sut.appear()

        connection.simulate(.connecting)
        XCTAssertEqual(info.loadCount, 0)

        connection.simulate(.connected)
        connection.simulate(.connected)
        XCTAssertEqual(info.loadCount, 1)

        connection.simulate(.connecting)
        connection.simulate(.connected)
        XCTAssertEqual(info.loadCount, 2)
    }

    func test_info_deliversInfoViewModelOnSuccess() {
        let (sut, connection, _, info, _, _) = makeSUT()
        var received: [PlantDeviceInfoViewModel] = []
        sut.loadedInfo = { received.append($0) }
        sut.appear()

        connection.simulate(.connected)
        info.completeLoad(with: anyDeviceInfo())

        XCTAssertEqual(received.map(\.firmware), ["0.1.0"])
        XCTAssertEqual(received.map(\.interval), ["Every 30 s"])
    }

    func test_info_deliversNothingOnFailure() {
        let (sut, connection, _, info, _, _) = makeSUT()
        var received: [PlantDeviceInfoViewModel] = []
        sut.loadedInfo = { received.append($0) }
        sut.appear()

        connection.simulate(.connected)
        info.completeLoad(with: anyNSError())

        XCTAssertEqual(received, [])
    }

    func test_readNowTap_sendsReadNow() {
        let (sut, _, _, _, commands, _) = makeSUT()

        sut.readNowTap()

        XCTAssertEqual(commands.commands, [.readNow])
    }

    func test_readNowTap_deliversErrorMessageOnFailureAndClearsOnSuccess() {
        let (sut, _, _, _, commands, _) = makeSUT()
        var messages: [String?] = []
        sut.loadedCommandError = { messages.append($0) }

        sut.readNowTap()
        commands.completeSend(with: anyNSError())
        sut.readNowTap()
        commands.completeSend(with: nil, at: 1)

        XCTAssertEqual(messages, [String.localised(key: "plant.device.command.error"), nil])
    }

    func test_forgetTap_forgetsPairedDevice() {
        let (sut, _, pairing, _, _, _) = makeSUT()

        sut.forgetTap()

        XCTAssertEqual(pairing.messages, [.forget])
    }

    func test_pairTap_deliversPairTapAction() {
        var actions: [PlantDeviceAction] = []
        let (sut, _, _, _, _, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.pairTap()

        XCTAssertEqual(actions, [.pairTap])
    }

    func test_openSettingsTap_deliversOpenSettingsAction() {
        var actions: [PlantDeviceAction] = []
        let (sut, _, _, _, _, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.openSettingsTap()

        XCTAssertEqual(actions, [.openSettings])
    }

    func test_clearHistoryConfirmTap_deliversClearSensorHistoryAction() {
        var actions: [PlantDeviceAction] = []
        let (sut, _, _, _, _, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.clearHistoryConfirmTap()

        XCTAssertEqual(actions, [.clearSensorHistory])
    }

    func test_modeSelect_savesModeAndDeliversActionOnChange() {
        var actions: [PlantDeviceAction] = []
        let (sut, _, _, _, _, defaults) = makeSUT(actionHandler: { actions.append($0) })
        var modes: [PlantDeviceMode] = []
        sut.loadedMode = { modes.append($0) }

        sut.modeSelect(.sensor)

        XCTAssertTrue(defaults.messages.contains(.setString("sensor", forKey: PlantDeviceSettings.modeKey)))
        XCTAssertEqual(modes, [.sensor])
        XCTAssertEqual(actions, [.modeChanged(.sensor)])
    }

    func test_modeSelect_doesNothingWhenModeIsUnchanged() {
        var actions: [PlantDeviceAction] = []
        let (sut, _, _, _, _, defaults) = makeSUT(actionHandler: { actions.append($0) })
        defaults.stub("sensor", forKey: PlantDeviceSettings.modeKey)

        sut.modeSelect(.sensor)

        XCTAssertEqual(actions, [])
        XCTAssertFalse(defaults.messages.contains(.setString("sensor", forKey: PlantDeviceSettings.modeKey)))
    }

    func test_modes_listsSimulatedThenSensor() {
        let (sut, _, _, _, _, _) = makeSUT()

        XCTAssertEqual(sut.modes.map(\.mode), [.simulated, .sensor])
        XCTAssertEqual(sut.modes.map(\.label), ["Simulated plant", "Real sensor"])
    }

    func test_appear_doesNotCreateMemoryLeaks() {
        let connection = ConnectionLoaderStub()
        let pairing = PairingLoaderStub()
        let info = InfoLoaderStub()
        let commands = CommandSenderStub()
        var sut: PlantDeviceViewModel? = PlantDeviceViewModel(
            connectionLoader: connection,
            pairingLoader: pairing,
            infoLoader: info,
            calibrationLoader: LocalMoistureCalibrationLoader(defaults: DefaultsSpy()),
            rawReadingLoader: RawReadingLoaderStub(),
            commandSender: commands,
            settings: PlantDeviceSettings(defaults: DefaultsSpy()),
            actionHandler: { _ in }
        )
        weak var weakSUT = sut

        sut?.appear()
        connection.simulate(.connected)
        sut?.readNowTap()

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    func test_appear_deliversCalibrationStatusOnEveryAppear() {
        let (sut, _, _, _, _, defaults) = makeSUT()
        var statuses: [String] = []
        sut.loadedCalibrationStatus = { statuses.append($0) }

        sut.appear()
        defaults.stub(2400.0, forKey: LocalMoistureCalibrationLoader.dryKey)
        defaults.stub(1100.0, forKey: LocalMoistureCalibrationLoader.wetKey)
        sut.appear()

        XCTAssertEqual(statuses, ["Not calibrated", "Calibrated"])
    }

    func test_appear_subscribesToRawReadingsOnce() {
        let raw = RawReadingLoaderStub()
        let (sut, _, _, _, _, _) = makeSUT(raw: raw)

        sut.appear()
        sut.appear()

        XCTAssertEqual(raw.subscriptionCount, 1)
    }

    func test_calibrationTap_deliversCalibrationTapAction() {
        var actions: [PlantDeviceAction] = []
        let (sut, _, _, _, _, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.calibrationTap()

        XCTAssertEqual(actions, [.calibrationTap])
    }

    func test_connection_loadsRawReadingOnEachTransitionIntoConnected() {
        let raw = RawReadingLoaderStub()
        let (sut, connection, _, _, _, _) = makeSUT(raw: raw)
        var received: [PlantDeviceRawReadingViewModel] = []
        sut.loadedRawReading = { received.append($0) }
        sut.appear()

        connection.simulate(.connecting)
        XCTAssertEqual(raw.loadCount, 0)

        connection.simulate(.connected)
        connection.simulate(.connected)
        XCTAssertEqual(raw.loadCount, 1)

        raw.completeLoad(with: anyRawReading(sequence: 7))
        XCTAssertEqual(received.map(\.sequence), ["#7"])

        connection.simulate(.connecting)
        connection.simulate(.connected)
        XCTAssertEqual(raw.loadCount, 2)
    }

    func test_rawReadingNotify_deliversRawReadingViewModel() {
        let raw = RawReadingLoaderStub()
        let (sut, _, _, _, _, _) = makeSUT(raw: raw)
        var received: [PlantDeviceRawReadingViewModel] = []
        sut.loadedRawReading = { received.append($0) }
        sut.appear()

        raw.simulate(anyRawReading(sequence: 1))
        raw.simulate(error: anyNSError())
        raw.simulate(anyRawReading(sequence: 2))

        XCTAssertEqual(received.map(\.sequence), ["#1", "#2"])
    }

    // MARK: - Private helpers

    private func makeSUT(
        raw: RawReadingLoaderStub = RawReadingLoaderStub(),
        actionHandler: @escaping (PlantDeviceAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: PlantDeviceViewModel,
        connection: ConnectionLoaderStub,
        pairing: PairingLoaderStub,
        info: InfoLoaderStub,
        commands: CommandSenderStub,
        defaults: DefaultsSpy
    ) {
        let connection = ConnectionLoaderStub()
        let pairing = PairingLoaderStub()
        let info = InfoLoaderStub()
        let commands = CommandSenderStub()
        let defaults = DefaultsSpy()
        let sut = PlantDeviceViewModel(
            connectionLoader: connection,
            pairingLoader: pairing,
            infoLoader: info,
            calibrationLoader: LocalMoistureCalibrationLoader(defaults: defaults),
            rawReadingLoader: raw,
            commandSender: commands,
            settings: PlantDeviceSettings(defaults: defaults),
            actionHandler: actionHandler
        )
        trackMemoryLeak(raw, file: file, line: line)
        trackMemoryLeak(connection, file: file, line: line)
        trackMemoryLeak(pairing, file: file, line: line)
        trackMemoryLeak(info, file: file, line: line)
        trackMemoryLeak(commands, file: file, line: line)
        trackMemoryLeak(defaults, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, connection, pairing, info, commands, defaults)
    }
}
