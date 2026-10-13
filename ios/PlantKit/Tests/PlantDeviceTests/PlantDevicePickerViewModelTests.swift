import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PlantDevicePickerViewModelTests: PlantDeviceXCTestCase {
    func test_init_doesNotMessageCollaborators() {
        let (_, scan, connection, pairing) = makeSUT()

        XCTAssertEqual(scan.messages, [])
        XCTAssertEqual(connection.subscriptionCount, 0)
        XCTAssertEqual(pairing.messages, [])
    }

    func test_appear_startsScanOnce() {
        let (sut, scan, connection, _) = makeSUT()

        sut.appear()
        sut.appear()

        XCTAssertEqual(scan.messages, [.start])
        XCTAssertEqual(connection.subscriptionCount, 1)
    }

    func test_disappear_stopsScanOnce() {
        let (sut, scan, _, _) = makeSUT()

        sut.appear()
        sut.disappear()
        sut.disappear()

        XCTAssertEqual(scan.messages, [.start, .stop])
    }

    func test_disappearWithoutAppear_doesNotStop() {
        let (sut, scan, _, _) = makeSUT()

        sut.disappear()

        XCTAssertEqual(scan.messages, [])
    }

    func test_appearAfterDisappear_restartsScan() {
        let (sut, scan, connection, _) = makeSUT()

        sut.appear()
        sut.disappear()
        sut.appear()

        XCTAssertEqual(scan.messages, [.start, .stop, .start])
        XCTAssertEqual(connection.subscriptionCount, 1)
    }

    func test_candidates_mergeByIdentifierWithLatestSignalWinning() {
        let (sut, scan, _, _) = makeSUT()
        var received: [[PlantDeviceCandidateViewModel]] = []
        sut.loadedCandidates = { received.append($0) }
        let first = makeCandidate(identifier: id(1), name: "TalkingPlant-A", rssi: -90)
        let second = makeCandidate(identifier: id(1), name: "TalkingPlant-A", rssi: -50)

        sut.appear()
        scan.simulate(first)
        scan.simulate(second)

        XCTAssertEqual(received.map { $0.map(\.candidate) }, [[first], [second]])
    }

    func test_candidates_areSortedByName() {
        let (sut, scan, _, _) = makeSUT()
        var received: [[String]] = []
        sut.loadedCandidates = { received.append($0.map(\.name)) }

        sut.appear()
        scan.simulate(makeCandidate(identifier: id(1), name: "TalkingPlant-C"))
        scan.simulate(makeCandidate(identifier: id(2), name: "TalkingPlant-A"))
        scan.simulate(makeCandidate(identifier: id(3), name: "TalkingPlant-B"))
        scan.simulate(makeCandidate(identifier: id(2), name: "TalkingPlant-A", rssi: -40))

        XCTAssertEqual(received.last, ["TalkingPlant-A", "TalkingPlant-B", "TalkingPlant-C"])
    }

    func test_signalBars_followThresholds() {
        let cases: [(rssi: Int, bars: Int)] = [
            (-30, 3), (-60, 3), (-61, 2), (-75, 2), (-76, 1), (-100, 1)
        ]

        cases.forEach { rssi, bars in
            let sut = PlantDeviceCandidateViewModel(candidate: makeCandidate(rssi: rssi))
            XCTAssertEqual(sut.signalBars, bars, "rssi \(rssi)")
        }
    }

    func test_emptyText_isLookingBeforeAnyConnectionState() {
        let (sut, _, _, _) = makeSUT()
        var texts: [String] = []
        sut.loadedEmptyText = { texts.append($0) }

        sut.appear()

        XCTAssertEqual(texts, [String.localised(key: "plant.device.picker.empty.looking")])
    }

    func test_emptyText_followsConnection() {
        let (sut, _, connection, _) = makeSUT()
        var texts: [String] = []
        sut.loadedEmptyText = { texts.append($0) }
        sut.appear()
        texts.removeAll()

        connection.simulate(.bluetoothOff)
        connection.simulate(.bluetoothUnauthorized)
        connection.simulate(.bluetoothUnsupported)
        connection.simulate(.connecting)
        connection.simulate(.notPaired)

        let looking = String.localised(key: "plant.device.picker.empty.looking")
        XCTAssertEqual(texts, [
            String.localised(key: "plant.device.picker.empty.bluetoothOff"),
            String.localised(key: "plant.device.picker.empty.bluetoothUnauthorized"),
            String.localised(key: "plant.device.picker.empty.bluetoothUnsupported"),
            looking,
            looking
        ])
    }

    func test_select_stopsScanPairsAndSendsPaired() {
        var actions: [PlantDeviceAction] = []
        let (sut, scan, _, pairing) = makeSUT(actionHandler: { actions.append($0) })
        let candidate = makeCandidate(identifier: id(1), name: "TalkingPlant-A")
        var rows: [PlantDeviceCandidateViewModel] = []
        sut.loadedCandidates = { rows = $0 }
        sut.appear()
        scan.simulate(candidate)

        sut.select(rows[0])

        XCTAssertEqual(scan.messages, [.start, .stop])
        XCTAssertEqual(pairing.messages, [.pair(candidate)])
        XCTAssertEqual(actions, [.paired])
    }

    func test_disappearAfterSelect_doesNotStopAgain() {
        let (sut, scan, _, _) = makeSUT()
        var rows: [PlantDeviceCandidateViewModel] = []
        sut.loadedCandidates = { rows = $0 }
        sut.appear()
        scan.simulate(makeCandidate())

        sut.select(rows[0])
        sut.disappear()

        XCTAssertEqual(scan.messages, [.start, .stop])
    }

    func test_title_isLocalised() {
        let (sut, _, _, _) = makeSUT()

        XCTAssertEqual(sut.title, String.localised(key: "plant.device.picker.title"))
    }

    // MARK: - Private helpers

    private func makeSUT(
        actionHandler: @escaping (PlantDeviceAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: PlantDevicePickerViewModel,
        scan: ScanLoaderStub,
        connection: ConnectionLoaderStub,
        pairing: PairingLoaderStub
    ) {
        let scan = ScanLoaderStub()
        let connection = ConnectionLoaderStub()
        let pairing = PairingLoaderStub()
        let sut = PlantDevicePickerViewModel(
            scanLoader: scan,
            connectionLoader: connection,
            pairingLoader: pairing,
            actionHandler: actionHandler
        )
        trackMemoryLeak(scan, file: file, line: line)
        trackMemoryLeak(connection, file: file, line: line)
        trackMemoryLeak(pairing, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, scan, connection, pairing)
    }

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-00000000000\(n)")!
    }

    private func makeCandidate(identifier: UUID? = nil, name: String = "TalkingPlant-TEST", rssi: Int = -50) -> PlantDeviceCandidate {
        PlantDeviceCandidate(identifier: identifier ?? anyIdentifier(), name: name, rssi: rssi)
    }
}
