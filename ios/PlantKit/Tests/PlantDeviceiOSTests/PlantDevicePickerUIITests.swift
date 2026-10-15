import PlantDevice
import PlantDeviceiOS
import PlantShared
import XCTest

@MainActor
final class PlantDevicePickerUIITests: PlantDeviceiOSXCTestCase {
    func test_init_doesNotMessageLoaders() {
        let (_, scan, pairing, _) = makePickerSUT()

        XCTAssertEqual(scan.messages, [])
        XCTAssertEqual(pairing.messages, [])
    }

    func test_appearAndDisappear_startAndStopScan() {
        let (sut, scan, _, _) = makePickerSUT()

        sut.simulateAppear()
        sut.simulateDisappear()

        XCTAssertEqual(scan.messages, [.start, .stop])
    }

    func test_noCandidates_showsLookingText() {
        let (sut, _, _, _) = makePickerSUT()

        sut.simulateAppear()

        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.picker.empty.looking")))
    }

    func test_noCandidatesAndBluetoothOff_showsBluetoothOffText() {
        let (sut, _, _, connection) = makePickerSUT()

        sut.simulateAppear()
        connection.simulate(.bluetoothOff)

        XCTAssertTrue(sut.texts.contains(String.localised(key: "plant.device.picker.empty.bluetoothOff")))
    }

    func test_candidates_showRowsSortedByNameAndHideEmptyText() {
        let (sut, scan, _, _) = makePickerSUT()

        sut.simulateAppear()
        scan.simulate(makeCandidate(name: "TalkingPlant-B", id: "2"))
        scan.simulate(makeCandidate(name: "TalkingPlant-A", id: "1"))

        XCTAssertEqual(sut.texts, ["TalkingPlant-A", "TalkingPlant-B"])
    }

    func test_candidateTap_stopsScanPairsAndSendsPaired() {
        var actions: [PlantDeviceAction] = []
        let (sut, scan, pairing, _) = makePickerSUT(actionHandler: { actions.append($0) })
        let candidate = makeCandidate(name: "TalkingPlant-A", id: "1")

        sut.simulateAppear()
        scan.simulate(candidate)
        sut.simulateTap("TalkingPlant-A")

        XCTAssertEqual(scan.messages, [.start, .stop])
        XCTAssertEqual(pairing.messages, [.pair(candidate)])
        XCTAssertEqual(actions, [.paired])
    }

    func test_picker_candidateTap_playsTapAndStillPairs() {
        var actions: [PlantDeviceAction] = []
        let haptics = HapticsSpy()
        let (sut, scan, pairing, _) = makePickerSUT(haptics: haptics, actionHandler: { actions.append($0) })
        let candidate = PlantDeviceCandidate(
            identifier: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "TalkingPlant-A",
            rssi: -50
        )
        sut.simulateAppear()
        scan.simulate(candidate)
        XCTAssertEqual(haptics.played, [])

        sut.simulateTap("TalkingPlant-A")

        XCTAssertEqual(haptics.played, [.tap])
        XCTAssertEqual(pairing.messages, [.pair(candidate)])
        XCTAssertEqual(actions, [.paired])
    }

    // MARK: - Private helpers

    private func makePickerSUT(
        haptics: HapticsSpy = HapticsSpy(),
        actionHandler: @escaping (PlantDeviceAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: PlantDevicePickerView,
        scan: ScanLoaderStub,
        pairing: PairingLoaderStub,
        connection: ConnectionLoaderStub
    ) {
        let scan = ScanLoaderStub()
        let pairing = PairingLoaderStub()
        let connection = ConnectionLoaderStub()
        let sut = PlantDeviceUIComposer.composedPicker(
            scanLoader: scan,
            connectionLoader: connection,
            pairingLoader: pairing,
            haptics: haptics,
            actionHandler: actionHandler
        )
        trackMemoryLeak(haptics, file: file, line: line)
        trackMemoryLeak(scan, file: file, line: line)
        trackMemoryLeak(pairing, file: file, line: line)
        trackMemoryLeak(connection, file: file, line: line)
        return (sut, scan, pairing, connection)
    }

    private func makeCandidate(name: String, id: String, rssi: Int = -50) -> PlantDeviceCandidate {
        PlantDeviceCandidate(
            identifier: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(id)")!,
            name: name,
            rssi: rssi
        )
    }
}
