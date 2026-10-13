import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PeripheralPlantDeviceRawReadingLoaderTests: PlantDeviceXCTestCase {
    /// Contract fixture: soil 2500 mV, 1000 lx, 23.50 °C, 55.20 %, flags 0x07, sequence 42.
    private let readingFixture = Data([0x01, 0x07, 0xC4, 0x09, 0xE8, 0x03, 0x2E, 0x09, 0x90, 0x15, 0x00, 0x00, 0x2A, 0x00, 0x00, 0x00])

    func test_init_doesNotMessageClient() {
        let (_, client) = makeSUT()

        XCTAssertEqual(client.messages, [])
    }

    func test_load_readsReadingsOnClient() {
        let (sut, client) = makeSUT()

        sut.load { _ in }

        XCTAssertEqual(client.messages, [.read(.readings)])
    }

    func test_subscribe_subscribesToReadingsOnce() {
        let (sut, client) = makeSUT()

        sut.subscribe { _ in }

        XCTAssertEqual(client.messages, [.subscribe(.readings)])
    }

    func test_load_deliversRawReadingOnContractFixture() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let (sut, client) = makeSUT(currentDate: { now })

        let result = load(from: sut, when: { client.completeRead(with: readingFixture) })

        XCTAssertEqual(try XCTUnwrap(result).get(), PlantDeviceRawReading(
            soilMillivolts: 2500,
            lux: 1000,
            temperature: 23.5,
            humidity: 55.2,
            flags: 0x07,
            sequence: 42,
            receivedAt: now
        ))
    }

    func test_subscribe_deliversRawReadingOnNotification() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let (sut, client) = makeSUT(currentDate: { now })
        var received: PlantDeviceRawReadingLoader.Result?
        sut.subscribe { received = $0 }

        client.simulateUpdate(with: readingFixture)

        let reading = try XCTUnwrap(received).get()
        XCTAssertEqual(reading.soilMillivolts, 2500)
        XCTAssertEqual(reading.sequence, 42)
        XCTAssertEqual(reading.receivedAt, now)
    }

    func test_load_deliversNilFieldsWhenFlagsAreClear() throws {
        let (sut, client) = makeSUT()
        var packet = readingFixture
        packet[1] = 0x00

        let reading = try XCTUnwrap(load(from: sut, when: { client.completeRead(with: packet) })).get()

        XCTAssertNil(reading.soilMillivolts)
        XCTAssertNil(reading.lux)
        XCTAssertNil(reading.temperature)
        XCTAssertNil(reading.humidity)
        XCTAssertEqual(reading.flags, 0x00)
    }

    func test_load_deliversInvalidDataErrorOnWrongLength() {
        for length in [0, 8, 15, 17] {
            let (sut, client) = makeSUT()

            let result = load(from: sut, when: { client.completeRead(with: Data(repeating: 1, count: length)) })

            XCTAssertThrowsError(try result?.get(), "length \(length)") { error in
                XCTAssertEqual(error as? PeripheralPlantDeviceRawReadingLoader.Error, .invalidData, "length \(length)")
            }
        }
    }

    func test_load_deliversInvalidDataErrorOnUnsupportedVersion() {
        for version in [UInt8(0), 2] {
            let (sut, client) = makeSUT()
            var packet = readingFixture
            packet[0] = version

            let result = load(from: sut, when: { client.completeRead(with: packet) })

            XCTAssertThrowsError(try result?.get(), "version \(version)") { error in
                XCTAssertEqual(error as? PeripheralPlantDeviceRawReadingLoader.Error, .invalidData, "version \(version)")
            }
        }
    }

    func test_load_deliversConnectivityErrorOnClientFailure() {
        let (sut, client) = makeSUT()

        let result = load(from: sut, when: { client.completeRead(with: anyNSError()) })

        XCTAssertThrowsError(try result?.get()) { error in
            XCTAssertEqual(error as? PeripheralPlantDeviceRawReadingLoader.Error, .connectivity)
        }
    }

    func test_subscribe_deliversConnectivityErrorOnClientFailure() {
        let (sut, client) = makeSUT()
        var received: PlantDeviceRawReadingLoader.Result?
        sut.subscribe { received = $0 }

        client.simulateUpdate(with: anyNSError())

        XCTAssertThrowsError(try received?.get()) { error in
            XCTAssertEqual(error as? PeripheralPlantDeviceRawReadingLoader.Error, .connectivity)
        }
    }

    func test_load_doesNotCreateMemoryLeaks() {
        let client = ClientSpy()
        var sut: PeripheralPlantDeviceRawReadingLoader? = PeripheralPlantDeviceRawReadingLoader(client: client)
        weak let weakSUT = sut

        sut?.load { _ in }
        sut?.subscribe { _ in }

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(
        currentDate: @escaping () -> Date = Date.init,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PeripheralPlantDeviceRawReadingLoader, client: ClientSpy) {
        let client = ClientSpy()
        let sut = PeripheralPlantDeviceRawReadingLoader(client: client, currentDate: currentDate)
        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, client)
    }

    private func load(from sut: PeripheralPlantDeviceRawReadingLoader, when action: () -> Void) -> PlantDeviceRawReadingLoader.Result? {
        var received: PlantDeviceRawReadingLoader.Result?
        sut.load { received = $0 }
        action()
        return received
    }
}
