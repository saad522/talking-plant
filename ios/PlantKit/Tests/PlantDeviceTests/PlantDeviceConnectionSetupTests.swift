import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PlantDeviceConnectionSetupTests: PlantDeviceXCTestCase {
    func test_init_doesNotLoadOrSend() {
        let (_, _, info, commands) = makeSUT()

        XCTAssertEqual(info.loadCount, 0)
        XCTAssertEqual(commands.commands, [])
    }

    func test_start_doesNothingUntilConnected() {
        let (sut, connection, info, commands) = makeSUT()
        sut.start()

        [PlantConnection.notPaired, .connecting, .offline, .bluetoothOff, .incompatible].forEach { connection.simulate($0) }

        XCTAssertEqual(info.loadCount, 0)
        XCTAssertEqual(commands.commands, [])
    }

    func test_connected_loadsDeviceInfoFirst() {
        let (sut, connection, info, commands) = makeSUT()
        sut.start()

        connection.simulate(.connected)

        XCTAssertEqual(info.loadCount, 1)
        XCTAssertEqual(commands.commands, [])
    }

    func test_connected_sendsSetIntervalThenReadNowInOrder() {
        let (sut, connection, info, commands) = makeSUT(readingInterval: 300)
        sut.start()
        connection.simulate(.connected)

        info.completeLoad(with: anyDeviceInfo())
        XCTAssertEqual(commands.commands, [.setInterval(seconds: 300)])

        commands.completeSend(with: nil, at: 0)
        XCTAssertEqual(commands.commands, [.setInterval(seconds: 300), .readNow])
    }

    func test_connected_sendsNothingOnDeviceInfoFailure() {
        let (sut, connection, info, commands) = makeSUT()
        sut.start()
        connection.simulate(.connected)

        info.completeLoad(with: PeripheralPlantDeviceInfoLoader.Error.connectivity)

        XCTAssertEqual(commands.commands, [])
    }

    func test_connected_sendsNothingOnUnsupportedProtocolVersion() {
        let (sut, connection, info, commands) = makeSUT()
        sut.start()
        connection.simulate(.connected)

        info.completeLoad(with: PeripheralPlantDeviceInfoLoader.Error.invalidData)

        XCTAssertEqual(commands.commands, [])
    }

    func test_connected_doesNotSendReadNowWhenSetIntervalFails() {
        let (sut, connection, info, commands) = makeSUT(readingInterval: 300)
        sut.start()
        connection.simulate(.connected)
        info.completeLoad(with: anyDeviceInfo())

        commands.completeSend(with: PeripheralPlantDeviceCommandSender.Error.connectivity, at: 0)

        XCTAssertEqual(commands.commands, [.setInterval(seconds: 300)])
    }

    func test_connected_runsAgainAfterReconnect() {
        let (sut, connection, info, commands) = makeSUT(readingInterval: 300)
        sut.start()
        connection.simulate(.connected)
        info.completeLoad(with: anyDeviceInfo(), at: 0)
        commands.completeSend(with: nil, at: 0)

        connection.simulate(.connecting)
        connection.simulate(.connected)
        info.completeLoad(with: anyDeviceInfo(), at: 1)

        XCTAssertEqual(info.loadCount, 2)
        XCTAssertEqual(commands.commands, [.setInterval(seconds: 300), .readNow, .setInterval(seconds: 300)])
    }

    func test_connected_doesNotRunTwiceForRepeatedConnected() {
        let (sut, connection, info, _) = makeSUT()
        sut.start()

        connection.simulate(.connected)
        connection.simulate(.connected)

        XCTAssertEqual(info.loadCount, 1)
    }

    func test_connected_ignoresDeviceInfoThatArrivesAfterDisconnect() {
        let (sut, connection, info, commands) = makeSUT()
        sut.start()
        connection.simulate(.connected)
        connection.simulate(.connecting)

        info.completeLoad(with: anyDeviceInfo())

        XCTAssertEqual(commands.commands, [])
    }

    func test_start_doesNotCreateMemoryLeaks() {
        let connection = ConnectionLoaderStub()
        let info = InfoLoaderStub()
        let commands = CommandSenderStub()
        var sut: PlantDeviceConnectionSetup? = PlantDeviceConnectionSetup(
            connection: connection,
            infoLoader: info,
            commands: commands,
            readingInterval: 300
        )
        weak let weakSUT = sut

        sut?.start()
        connection.simulate(.connected)

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(
        readingInterval: UInt16 = 300,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantDeviceConnectionSetup, connection: ConnectionLoaderStub, info: InfoLoaderStub, commands: CommandSenderStub) {
        let connection = ConnectionLoaderStub()
        let info = InfoLoaderStub()
        let commands = CommandSenderStub()
        let sut = PlantDeviceConnectionSetup(connection: connection, infoLoader: info, commands: commands, readingInterval: readingInterval)
        trackMemoryLeak(connection, file: file, line: line)
        trackMemoryLeak(info, file: file, line: line)
        trackMemoryLeak(commands, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, connection, info, commands)
    }
}
