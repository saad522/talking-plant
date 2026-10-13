import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PeripheralPlantDeviceConnectionLoaderTests: PlantDeviceXCTestCase {
    func test_init_doesNotMessageClientOrSchedule() {
        let (_, client, schedule) = makeSUT()

        XCTAssertEqual(client.messages, [])
        XCTAssertEqual(schedule.intervals, [])
    }

    func test_subscribe_subscribesToClientState() {
        let (sut, client, _) = makeSUT()

        sut.subscribe { _ in }

        XCTAssertEqual(client.messages, [.subscribeState])
    }

    func test_subscribe_mapsEachClientStateToConnection() {
        let cases: [(PeripheralConnectionState, PlantConnection)] = [
            (.unsupported, .bluetoothUnsupported),
            (.unauthorized, .bluetoothUnauthorized),
            (.poweredOff, .bluetoothOff),
            (.idle, .notPaired),
            (.connecting, .connecting),
            (.connected, .connected),
            (.incompatible, .incompatible),
        ]

        for (state, expected) in cases {
            let (sut, client, _) = makeSUT()
            var received: [PlantConnection] = []
            sut.subscribe { received.append($0) }

            client.simulateState(state)

            XCTAssertEqual(received, [expected], "state \(state)")
        }
    }

    func test_subscribe_doesNotDeliverDuplicateStates() {
        let (sut, client, _) = makeSUT()
        var received: [PlantConnection] = []
        sut.subscribe { received.append($0) }

        client.simulateState(.connected)
        client.simulateState(.connected)
        client.simulateState(.poweredOff)
        client.simulateState(.poweredOff)

        XCTAssertEqual(received, [.connected, .bluetoothOff])
    }

    func test_subscribe_schedulesOfflineTickOnConnectingOnly() {
        let (sut, client, schedule) = makeSUT(offlineAfter: 20)
        sut.subscribe { _ in }

        client.simulateState(.idle)
        client.simulateState(.connected)
        XCTAssertEqual(schedule.intervals, [])

        client.simulateState(.connecting)
        XCTAssertEqual(schedule.intervals, [20])
    }

    func test_subscribe_deliversOfflineWhenStillConnectingAfterTick() {
        let (sut, client, schedule) = makeSUT()
        var received: [PlantConnection] = []
        sut.subscribe { received.append($0) }
        client.simulateState(.connecting)

        let repeats = schedule.fire()

        XCTAssertFalse(repeats)
        XCTAssertEqual(received, [.connecting, .offline])
    }

    func test_subscribe_ignoresTickWhenNewerStateArrivedBeforeIt() {
        let (sut, client, schedule) = makeSUT()
        var received: [PlantConnection] = []
        sut.subscribe { received.append($0) }
        client.simulateState(.connecting)
        client.simulateState(.connected)

        schedule.fire()

        XCTAssertEqual(received, [.connecting, .connected])
    }

    func test_subscribe_onlyLatestConnectingTickCanGoOffline() {
        let (sut, client, schedule) = makeSUT()
        var received: [PlantConnection] = []
        sut.subscribe { received.append($0) }
        client.simulateState(.connecting)
        client.simulateState(.connected)
        client.simulateState(.connecting)

        schedule.fire(at: 0)
        XCTAssertEqual(received, [.connecting, .connected, .connecting])

        schedule.fire(at: 1)
        XCTAssertEqual(received, [.connecting, .connected, .connecting, .offline])
    }

    func test_subscribe_deliversConnectedAfterOffline() {
        let (sut, client, schedule) = makeSUT()
        var received: [PlantConnection] = []
        sut.subscribe { received.append($0) }
        client.simulateState(.connecting)
        schedule.fire()

        client.simulateState(.connected)

        XCTAssertEqual(received, [.connecting, .offline, .connected])
    }

    func test_subscribe_doesNotCreateMemoryLeaks() {
        let client = ConnectionClientSpy()
        let schedule = ScheduleSpy()
        var sut: PeripheralPlantDeviceConnectionLoader? = PeripheralPlantDeviceConnectionLoader(client: client, schedule: schedule.schedule)
        weak let weakSUT = sut

        sut?.subscribe { _ in }
        client.simulateState(.connecting)

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(
        offlineAfter: TimeInterval = 20,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PeripheralPlantDeviceConnectionLoader, client: ConnectionClientSpy, schedule: ScheduleSpy) {
        let client = ConnectionClientSpy()
        let schedule = ScheduleSpy()
        let sut = PeripheralPlantDeviceConnectionLoader(client: client, offlineAfter: offlineAfter, schedule: schedule.schedule)
        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(schedule, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, client, schedule)
    }
}
