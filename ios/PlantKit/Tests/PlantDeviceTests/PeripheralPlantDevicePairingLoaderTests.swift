import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PeripheralPlantDevicePairingLoaderTests: PlantDeviceXCTestCase {
    func test_init_doesNotMessageClient() {
        let (_, client, _) = makeSUT()

        XCTAssertEqual(client.messages, [])
    }

    func test_subscribe_deliversNilWhenNothingIsSaved() {
        let (sut, client, _) = makeSUT()
        var received: [PlantPairedDevice?] = []

        sut.subscribe { received.append($0) }

        XCTAssertEqual(received, [nil])
        XCTAssertEqual(client.messages, [])
    }

    func test_subscribe_deliversSavedDeviceFirst() {
        let (sut, _, settings) = makeSUT()
        let device = makeDevice()
        settings.savePairedDevice(device)
        var received: [PlantPairedDevice?] = []

        sut.subscribe { received.append($0) }

        XCTAssertEqual(received, [device])
    }

    func test_pair_savesConnectsAndNotifies() {
        let (sut, client, settings) = makeSUT()
        var received: [PlantPairedDevice?] = []
        sut.subscribe { received.append($0) }

        sut.pair(PlantDeviceCandidate(identifier: anyIdentifier(), name: "TalkingPlant-A1B2", rssi: -50))

        XCTAssertEqual(settings.loadPairedDevice(), makeDevice())
        XCTAssertEqual(client.messages, [.connect(anyIdentifier(), "TalkingPlant-A1B2")])
        XCTAssertEqual(received, [nil, makeDevice()])
    }

    func test_forget_clearsDisconnectsAndNotifies() {
        let (sut, client, settings) = makeSUT()
        settings.savePairedDevice(makeDevice())
        var received: [PlantPairedDevice?] = []
        sut.subscribe { received.append($0) }

        sut.forget()

        XCTAssertNil(settings.loadPairedDevice())
        XCTAssertEqual(client.messages, [.disconnect])
        XCTAssertEqual(received, [makeDevice(), nil])
    }

    func test_connectSaved_connectsToSavedDevice() {
        let (sut, client, settings) = makeSUT()
        settings.savePairedDevice(makeDevice())

        sut.connectSaved()

        XCTAssertEqual(client.messages, [.connect(anyIdentifier(), "TalkingPlant-A1B2")])
    }

    func test_connectSaved_doesNothingWithoutSavedDevice() {
        let (sut, client, _) = makeSUT()

        sut.connectSaved()

        XCTAssertEqual(client.messages, [])
    }

    func test_subscribe_doesNotCreateMemoryLeaks() {
        let client = ConnectionClientSpy()
        var sut: PeripheralPlantDevicePairingLoader? = PeripheralPlantDevicePairingLoader(
            client: client,
            settings: PlantDeviceSettings(defaults: DefaultsSpy())
        )
        weak let weakSUT = sut

        sut?.subscribe { _ in }

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeDevice() -> PlantPairedDevice {
        PlantPairedDevice(identifier: anyIdentifier(), name: "TalkingPlant-A1B2")
    }

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PeripheralPlantDevicePairingLoader, client: ConnectionClientSpy, settings: PlantDeviceSettings) {
        let client = ConnectionClientSpy()
        let defaults = DefaultsSpy()
        let settings = PlantDeviceSettings(defaults: defaults)
        let sut = PeripheralPlantDevicePairingLoader(client: client, settings: settings)
        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(defaults, file: file, line: line)
        trackMemoryLeak(settings, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, client, settings)
    }
}
