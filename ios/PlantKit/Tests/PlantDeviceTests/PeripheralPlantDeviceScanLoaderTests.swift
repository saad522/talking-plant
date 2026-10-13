import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PeripheralPlantDeviceScanLoaderTests: PlantDeviceXCTestCase {
    func test_init_doesNotMessageClient() {
        let (_, client) = makeSUT()

        XCTAssertEqual(client.messages, [])
    }

    func test_start_startsScanOnClient() {
        let (sut, client) = makeSUT()

        sut.start { _ in }

        XCTAssertEqual(client.messages, [.scan])
    }

    func test_stop_stopsScanOnClient() {
        let (sut, client) = makeSUT()

        sut.stop()

        XCTAssertEqual(client.messages, [.stopScan])
    }

    func test_start_deliversCandidateForPlantSensor() {
        let (sut, client) = makeSUT()
        var received: [PlantDeviceCandidate] = []
        sut.start { received.append($0) }

        client.simulateAdvertisement(PeripheralAdvertisement(identifier: anyIdentifier(), localName: "TalkingPlant-A1B2", rssi: -62))

        XCTAssertEqual(received, [PlantDeviceCandidate(identifier: anyIdentifier(), name: "TalkingPlant-A1B2", rssi: -62)])
    }

    func test_start_deliversEveryRepeatedSighting() {
        let (sut, client) = makeSUT()
        var received: [Int] = []
        sut.start { received.append($0.rssi) }

        client.simulateAdvertisement(PeripheralAdvertisement(identifier: anyIdentifier(), localName: "TalkingPlant-A1B2", rssi: -62))
        client.simulateAdvertisement(PeripheralAdvertisement(identifier: anyIdentifier(), localName: "TalkingPlant-A1B2", rssi: -48))

        XCTAssertEqual(received, [-62, -48])
    }

    func test_start_dropsOtherNamesAndMissingName() {
        let (sut, client) = makeSUT()
        var received: [PlantDeviceCandidate] = []
        sut.start { received.append($0) }

        for name in [nil, "", "Talking", "Plant-A1B2", "MyHeadphones"] {
            client.simulateAdvertisement(PeripheralAdvertisement(identifier: anyIdentifier(), localName: name, rssi: -50))
        }

        XCTAssertEqual(received, [])
    }

    func test_start_dropsUnavailableRSSI() {
        let (sut, client) = makeSUT()
        var received: [PlantDeviceCandidate] = []
        sut.start { received.append($0) }

        client.simulateAdvertisement(PeripheralAdvertisement(identifier: anyIdentifier(), localName: "TalkingPlant-A1B2", rssi: 127))

        XCTAssertEqual(received, [])
    }

    func test_start_doesNotCreateMemoryLeaks() {
        let client = ConnectionClientSpy()
        var sut: PeripheralPlantDeviceScanLoader? = PeripheralPlantDeviceScanLoader(client: client)
        weak let weakSUT = sut

        sut?.start { _ in }

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: PeripheralPlantDeviceScanLoader, client: ConnectionClientSpy) {
        let client = ConnectionClientSpy()
        let sut = PeripheralPlantDeviceScanLoader(client: client)
        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, client)
    }
}
