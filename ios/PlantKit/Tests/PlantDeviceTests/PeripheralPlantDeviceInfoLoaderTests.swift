import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PeripheralPlantDeviceInfoLoaderTests: PlantDeviceXCTestCase {
    func test_init_doesNotMessageClient() {
        let (_, client) = makeSUT()

        XCTAssertEqual(client.messages, [])
    }

    func test_load_readsDeviceInfoOnClient() {
        let (sut, client) = makeSUT()

        sut.load { _ in }

        XCTAssertEqual(client.messages, [.read(.deviceInfo)])
    }

    func test_load_deliversConnectivityErrorOnClientFailure() {
        let (sut, client) = makeSUT()

        let result = load(from: sut, when: { client.completeRead(with: anyNSError()) })

        XCTAssertThrowsError(try result?.get()) { error in
            XCTAssertEqual(error as? PeripheralPlantDeviceInfoLoader.Error, .connectivity)
        }
    }

    func test_load_deliversInvalidDataErrorOnWrongLength() {
        for length in [0, 7, 9, 16] {
            let (sut, client) = makeSUT()

            let result = load(from: sut, when: { client.completeRead(with: Data(repeating: 1, count: length)) })

            XCTAssertThrowsError(try result?.get(), "length \(length)") { error in
                XCTAssertEqual(error as? PeripheralPlantDeviceInfoLoader.Error, .invalidData, "length \(length)")
            }
        }
    }

    func test_load_deliversInvalidDataErrorOnUnsupportedVersion() {
        for version in [UInt8(0), 2] {
            let (sut, client) = makeSUT()

            let result = load(from: sut, when: { client.completeRead(with: makeDeviceInfoPacket(protocolVersion: version)) })

            XCTAssertThrowsError(try result?.get(), "version \(version)") { error in
                XCTAssertEqual(error as? PeripheralPlantDeviceInfoLoader.Error, .invalidData, "version \(version)")
            }
        }
    }

    func test_load_deliversDeviceInfoOnContractFixture() throws {
        let (sut, client) = makeSUT()

        let result = load(from: sut, when: { client.completeRead(with: deviceInfoFixture) })

        let info = try XCTUnwrap(result).get()
        XCTAssertEqual(info.firmwareVersion, "1.2.3")
        XCTAssertEqual(info.intervalSeconds, 300)
        XCTAssertTrue(info.capabilities.isEmpty)
    }

    func test_load_doesNotCreateMemoryLeaks() {
        let client = ClientSpy()
        var sut: PeripheralPlantDeviceInfoLoader? = PeripheralPlantDeviceInfoLoader(client: client)
        weak let weakSUT = sut

        sut?.load { _ in }

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: PeripheralPlantDeviceInfoLoader, client: ClientSpy) {
        let client = ClientSpy()
        let sut = PeripheralPlantDeviceInfoLoader(client: client)
        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, client)
    }

    private func load(from sut: PeripheralPlantDeviceInfoLoader, when action: () -> Void) -> PlantDeviceInfoLoader.Result? {
        var received: PlantDeviceInfoLoader.Result?
        sut.load { received = $0 }
        action()
        return received
    }
}
