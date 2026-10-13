import PlantDevice
import PlantShared
import XCTest

@MainActor
final class PlantDeviceUIITests: PlantDeviceiOSXCTestCase {
    func test_init_doesNotMessageLoaders() {
        let (_, _, pairing, info, commands, _) = makeSUT()

        XCTAssertEqual(pairing.messages, [])
        XCTAssertEqual(info.loadCount, 0)
        XCTAssertEqual(commands.commands, [])
    }

    func test_appear_subscribesOnce() {
        let (sut, _, pairing, _, _, _) = makeSUT()

        sut.simulateAppear()
        sut.simulateAppear()

        XCTAssertEqual(pairing.messages, [.subscribe])
    }

    func test_simulatedMode_hidesSensorSection() {
        let (sut, _, _, _, _, _) = makeSUT(savedMode: .simulated)

        sut.simulateAppear()

        XCTAssertFalse(sut.texts.contains(String.localised(key: "plant.device.paired.label")))
        XCTAssertFalse(sut.hasButton(String.localised(key: "plant.device.pair.label")))
    }

    func test_sensorMode_showsSensorSection() {
        let (sut, connection, _, _, _, _) = makeSUT(savedMode: .sensor)

        sut.simulateAppear()
        connection.simulate(.notPaired)

        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.paired.label")))
        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.paired.none")))
        XCTAssertTrue(sut.hasButton(String.localised(key: "plant.device.pair.label")))
        XCTAssertFalse(sut.hasButton(String.localised(key: "plant.device.forget.label")))
    }

    func test_connection_showsStatusText() {
        let cases: [(PlantConnection, String)] = [
            (.connecting, "plant.device.connection.connecting.label"),
            (.offline, "plant.device.connection.offline.label"),
            (.bluetoothOff, "plant.device.connection.bluetoothOff.label"),
            (.incompatible, "plant.device.connection.incompatible.label")
        ]

        cases.forEach { connectionState, key in
            let (sut, connection, _, _, _, _) = makeSUT(savedMode: .sensor)

            sut.simulateAppear()
            connection.simulate(connectionState)

            XCTAssertTrue(sut.texts.contains(String.localised(key: key)), "Missing \(key)")
        }
    }

    func test_connectionUnauthorized_showsOpenSettingsButtonThatSendsAction() {
        var actions: [PlantDeviceAction] = []
        let (sut, connection, _, _, _, _) = makeSUT(savedMode: .sensor, actionHandler: { actions.append($0) })
        let label = String.localised(key: "plant.device.openSettings.label")

        sut.simulateAppear()
        connection.simulate(.connecting)
        XCTAssertFalse(sut.hasButton(label))

        connection.simulate(.bluetoothUnauthorized)
        XCTAssertTrue(sut.hasButton(label))
        sut.simulateTap(label)

        XCTAssertEqual(actions, [.openSettings])
    }

    func test_connected_showsFirmwareAndIntervalAfterInfoLoads() {
        let (sut, connection, _, info, _, _) = makeSUT(savedMode: .sensor)

        sut.simulateAppear()
        connection.simulate(.connected)
        XCTAssertFalse(sut.texts.contains(String.localised(key: "plant.device.firmware.label")))

        info.completeLoad(with: anyDeviceInfo(intervalSeconds: 300))

        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.firmware.label")))
        XCTAssertTrue(sut.texts.contains("0.1.0"))
        XCTAssertTrue(sut.texts.contains("Every 5 min"))
    }

    func test_disconnected_hidesFirmwareIntervalAndReadNow() {
        let (sut, connection, _, info, _, _) = makeSUT(savedMode: .sensor)
        let readNow = String.localised(key: "plant.device.readNow.label")

        sut.simulateAppear()
        connection.simulate(.connected)
        info.completeLoad(with: anyDeviceInfo())
        XCTAssertTrue(sut.hasButton(readNow))

        connection.simulate(.connecting)

        XCTAssertFalse(sut.hasButton(readNow))
        XCTAssertFalse(sut.texts.contains("0.1.0"))
    }

    func test_readNowTap_sendsReadNowCommand() {
        let (sut, connection, _, _, commands, _) = makeSUT(savedMode: .sensor)

        sut.simulateAppear()
        connection.simulate(.connected)
        sut.simulateTap(String.localised(key: "plant.device.readNow.label"))

        XCTAssertEqual(commands.commands, [.readNow])
    }

    func test_readNowFailure_showsErrorMessage() {
        let (sut, connection, _, _, commands, _) = makeSUT(savedMode: .sensor)

        sut.simulateAppear()
        connection.simulate(.connected)
        sut.simulateTap(String.localised(key: "plant.device.readNow.label"))
        commands.completeSend(with: anyNSError())

        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.command.error")))
    }

    func test_pairedDevice_showsNameChangeAndForgetButtons() {
        let (sut, connection, pairing, _, _, _) = makeSUT(savedMode: .sensor)

        sut.simulateAppear()
        connection.simulate(.connecting)
        pairing.simulate(anyPairedDevice())

        XCTAssertTrue(sut.texts.contains("TalkingPlant-TEST"))
        XCTAssertTrue(sut.hasButton(String.localised(key: "plant.device.change.label")))
        XCTAssertTrue(sut.hasButton(String.localised(key: "plant.device.forget.label")))
        XCTAssertFalse(sut.hasButton(String.localised(key: "plant.device.pair.label")))
    }

    func test_pairTap_sendsPairTapAction() {
        var actions: [PlantDeviceAction] = []
        let (sut, _, _, _, _, _) = makeSUT(savedMode: .sensor, actionHandler: { actions.append($0) })

        sut.simulateAppear()
        sut.simulateTap(String.localised(key: "plant.device.pair.label"))

        XCTAssertEqual(actions, [.pairTap])
    }

    func test_forgetTap_forgetsPairedDevice() {
        let (sut, _, pairing, _, _, _) = makeSUT(savedMode: .sensor)

        sut.simulateAppear()
        pairing.simulate(anyPairedDevice())
        sut.simulateTap(String.localised(key: "plant.device.forget.label"))

        XCTAssertEqual(pairing.messages, [.subscribe, .forget])
    }

    func test_modeSelect_showsSensorSectionAndSendsModeChangedAction() {
        var actions: [PlantDeviceAction] = []
        let (sut, _, _, _, _, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.simulateAppear()
        sut.simulateSelectMode(.sensor)

        XCTAssertEqual(actions, [.modeChanged(.sensor)])
        XCTAssertTrue(sut.hasButton(String.localised(key: "plant.device.pair.label")))
    }
}
