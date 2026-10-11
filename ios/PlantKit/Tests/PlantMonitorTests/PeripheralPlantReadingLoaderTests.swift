import PlantMonitor
import PlantShared
import XCTest

@MainActor
final class PeripheralPlantReadingLoaderTests: PlantMonitorXCTestCase {
    func test_init_doesNotMessageClient() {
        let (_, client) = makeSUT()

        XCTAssertEqual(client.messages, [])
    }

    // MARK: - Subscribe

    func test_subscribe_subscribesToReadingsOnClient() {
        let (sut, client) = makeSUT()

        sut.subscribe(update: { _ in })

        XCTAssertEqual(client.messages, [.subscribe(.readings)])
    }

    func test_subscribe_deliversConnectivityErrorOnClientFailure() {
        let (sut, client) = makeSUT()

        expect(
            reading: sut,
            toDeliver: .failure(PeripheralPlantReadingLoader.Error.connectivity),
            when: { client.completeSubscription(with: anyNSError()) }
        )
    }

    func test_subscribe_deliversInvalidDataErrorOnWrongPacketLength() {
        [0, 15, 17].forEach { length in
            let (sut, client) = makeSUT()

            expect(
                reading: sut,
                toDeliver: .failure(PeripheralPlantReadingLoader.Error.invalidData),
                when: { client.completeSubscription(with: Data(repeating: 1, count: length)) }
            )
        }
    }

    func test_subscribe_deliversInvalidDataErrorOnUnsupportedVersion() {
        [UInt8(0), 2].forEach { version in
            let (sut, client) = makeSUT()

            expect(
                reading: sut,
                toDeliver: .failure(PeripheralPlantReadingLoader.Error.invalidData),
                when: { client.completeSubscription(with: makeReadingPacket(version: version)) }
            )
        }
    }

    func test_subscribe_deliversReadingOnValidPacket() {
        let (sut, client) = makeSUT(currentDate: anyDate())
        let expected = PlantReading(
            moisture: MoistureCalibration.placeholder.moisturePercent(soilMillivolts: 2_500),
            lux: 1_000,
            temperature: 23.5,
            humidity: 55.2,
            batteryMillivolts: nil,
            sequence: 42,
            receivedAt: anyDate()
        )

        expect(
            reading: sut,
            toDeliver: .success(expected),
            when: { client.completeSubscription(with: makeReadingPacket()) }
        )
    }

    func test_subscribe_deliversContractFixture() {
        let (sut, client) = makeSUT(calibration: anyCalibration())

        expect(
            reading: sut,
            toDeliver: .success(makeReading(moisture: 25)),
            when: { client.completeSubscription(with: contractFixture) }
        )
    }

    func test_subscribe_deliversNilForEachClearedFlag() {
        let (sut, client) = makeSUT(calibration: anyCalibration())

        expect(
            reading: sut,
            toDeliver: .success(makeReading(moisture: nil, lux: 1_000, temperature: 23.5, humidity: 55.2)),
            when: { client.completeSubscription(with: makeReadingPacket(flags: 0b0110)) }
        )
    }

    func test_subscribe_deliversNegativeTemperature() {
        let (sut, client) = makeSUT(calibration: anyCalibration())

        expect(
            reading: sut,
            toDeliver: .success(makeReading(moisture: 25, temperature: -10.5)),
            when: { client.completeSubscription(with: makeReadingPacket(temperatureCenti: -1_050)) }
        )
    }

    func test_subscribe_deliversEveryUpdate() {
        let (sut, client) = makeSUT(calibration: anyCalibration())
        var received: [PlantReadingLoader.Result] = []
        sut.subscribe { received.append($0) }

        client.completeSubscription(with: makeReadingPacket(sequence: 1))
        client.completeSubscription(with: anyNSError())
        client.completeSubscription(with: makeReadingPacket(sequence: 2))

        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(try received[0].get().sequence, 1)
        XCTAssertThrowsError(try received[1].get())
        XCTAssertEqual(try received[2].get().sequence, 2)
    }

    func test_subscribe_readsCalibrationAndDateAtDeliveryTime() {
        var calibration = MoistureCalibration.placeholder
        var currentDate = anyDate()
        let client = ClientSpy()
        let sut = PeripheralPlantReadingLoader(client: client, calibration: { calibration }, currentDate: { currentDate })
        var received: [PlantReading] = []
        sut.subscribe { received.append(try! $0.get()) }

        calibration = anyCalibration()
        currentDate = anyDate().addingTimeInterval(60)
        client.completeSubscription(with: makeReadingPacket())

        XCTAssertEqual(received.first?.moisture, 25)
        XCTAssertEqual(received.first?.receivedAt, anyDate().addingTimeInterval(60))
    }

    func test_subscribe_doesNotCreateMemoryLeaks() {
        let client = ClientSpy()
        var sut: PeripheralPlantReadingLoader? = PeripheralPlantReadingLoader(client: client, calibration: { .placeholder })
        weak let weakSUT = sut

        sut?.subscribe(update: { _ in })

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Load

    func test_load_readsReadingsOnClient() {
        let (sut, client) = makeSUT()

        sut.load(completion: { _ in })

        XCTAssertEqual(client.messages, [.read(.readings)])
    }

    func test_load_deliversConnectivityErrorOnClientFailure() {
        let (sut, client) = makeSUT()
        var received: PlantReadingLoader.Result?
        sut.load { received = $0 }

        client.completeRead(with: anyNSError())

        XCTAssertThrowsError(try received?.get()) { error in
            XCTAssertEqual(error as? PeripheralPlantReadingLoader.Error, .connectivity)
        }
    }

    func test_load_deliversInvalidDataErrorOnInvalidPacket() {
        let (sut, client) = makeSUT()
        var received: PlantReadingLoader.Result?
        sut.load { received = $0 }

        client.completeRead(with: Data(repeating: 1, count: 15))

        XCTAssertThrowsError(try received?.get()) { error in
            XCTAssertEqual(error as? PeripheralPlantReadingLoader.Error, .invalidData)
        }
    }

    func test_load_deliversReadingOnValidPacket() throws {
        let (sut, client) = makeSUT(calibration: anyCalibration())
        var received: PlantReadingLoader.Result?
        sut.load { received = $0 }

        client.completeRead(with: contractFixture)

        XCTAssertEqual(try XCTUnwrap(received).get(), makeReading(moisture: 25))
    }

    func test_load_doesNotCreateMemoryLeaks() {
        let client = ClientSpy()
        var sut: PeripheralPlantReadingLoader? = PeripheralPlantReadingLoader(client: client, calibration: { .placeholder })
        weak let weakSUT = sut

        sut?.load(completion: { _ in })

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(
        calibration: MoistureCalibration = .placeholder,
        currentDate: Date = Date(timeIntervalSince1970: 1_000),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PeripheralPlantReadingLoader, client: ClientSpy) {
        let client = ClientSpy()
        let sut = PeripheralPlantReadingLoader(client: client, calibration: { calibration }, currentDate: { currentDate })
        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, client)
    }
}
