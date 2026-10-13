import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PeripheralPlantDeviceCommandSenderTests: PlantDeviceXCTestCase {
    func test_init_doesNotMessageClient() {
        let (_, client) = makeSUT()

        XCTAssertEqual(client.messages, [])
    }

    func test_send_writesMappedBytesToCommandCharacteristic() {
        let (sut, client) = makeSUT()

        sut.send(.readNow) { _ in }
        sut.send(.setInterval(seconds: 300)) { _ in }

        XCTAssertEqual(client.messages, [
            .write(Data([0x01]), .command),
            .write(Data([0x02, 0x2C, 0x01]), .command),
        ])
    }

    func test_send_deliversConnectivityErrorOnClientFailure() {
        let (sut, client) = makeSUT()
        var received: Error?
        sut.send(.readNow) { received = $0 }

        client.completeWrite(with: anyNSError())

        XCTAssertEqual(received as? PeripheralPlantDeviceCommandSender.Error, .connectivity)
    }

    func test_send_deliversNilOnSuccess() {
        let (sut, client) = makeSUT()
        var received: [Error?] = []
        sut.send(.readNow) { received.append($0) }

        client.completeWrite(with: nil)

        XCTAssertEqual(received.count, 1)
        XCTAssertNil(received[0])
    }

    func test_send_doesNotCreateMemoryLeaks() {
        let client = ClientSpy()
        var sut: PeripheralPlantDeviceCommandSender? = PeripheralPlantDeviceCommandSender(client: client)
        weak let weakSUT = sut

        sut?.send(.readNow) { _ in }

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: PeripheralPlantDeviceCommandSender, client: ClientSpy) {
        let client = ClientSpy()
        let sut = PeripheralPlantDeviceCommandSender(client: client)
        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, client)
    }
}
