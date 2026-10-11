import PlantShared
import XCTest

@MainActor
final class SimulatedPeripheralClientTests: PlantSharedXCTestCase {
    func test_init_doesNotScheduleTicks() {
        let (_, schedule) = makeSUT()

        XCTAssertEqual(schedule.intervals, [])
    }

    func test_read_deliversContractPacketForCurrentState() {
        let (sut, _) = makeSUT()

        let packet = read(sut)

        XCTAssertEqual(packet?.version, 1)
        XCTAssertEqual(packet?.flags, 0b0111)
        XCTAssertEqual(packet?.soilMillivolts, 1_100)
        XCTAssertEqual(packet?.batteryMillivolts, 0)
        XCTAssertEqual(packet?.sequence, 0)
    }

    func test_read_doesNotAdvanceTimeOrSchedule() {
        let (sut, schedule) = makeSUT()

        let first = read(sut)
        let second = read(sut)

        XCTAssertEqual(first, second)
        XCTAssertEqual(schedule.intervals, [])
    }

    func test_read_deliversUnsupportedCharacteristicErrorOnOtherCharacteristics() {
        let (sut, _) = makeSUT()

        for characteristic in [PlantCharacteristic.deviceInfo, .command] {
            var received: PeripheralClient.Result?
            sut.read(characteristic) { received = $0 }

            assertUnsupported(received, "\(characteristic)")
        }
    }

    func test_subscribe_deliversCurrentPacketImmediately() {
        let (sut, _) = makeSUT()

        let packets = subscribe(sut)

        XCTAssertEqual(packets(), [read(sut)].compactMap { $0 })
    }

    func test_subscribe_schedulesTicksOnceWithInjectedInterval() {
        let (sut, schedule) = makeSUT(tickInterval: 5)

        _ = subscribe(sut)
        _ = subscribe(sut)

        XCTAssertEqual(schedule.intervals, [5])
    }

    func test_subscribe_deliversUnsupportedCharacteristicErrorOnOtherCharacteristicsWithoutScheduling() {
        let (sut, schedule) = makeSUT()

        var received: PeripheralClient.Result?
        sut.subscribe(to: .deviceInfo) { received = $0 }

        assertUnsupported(received)
        XCTAssertEqual(schedule.intervals, [])
    }

    func test_tick_deliversNextPacketToEverySubscriber() {
        let (sut, schedule) = makeSUT()
        let first = subscribe(sut)
        let second = subscribe(sut)

        schedule.tick(times: 2)

        XCTAssertEqual(first().map(\.sequence), [0, 1, 2])
        XCTAssertEqual(second().map(\.sequence), [0, 1, 2])
    }

    func test_tick_driesSoilBySimulatedTimeElapsed() {
        // 2 s per tick × 1,800 = one simulated hour per tick.
        let (sut, schedule) = makeSUT(tickInterval: 2, timeScale: 1_800)
        let packets = subscribe(sut)

        schedule.tick(times: 3)

        XCTAssertEqual(packets().map(\.soilMillivolts), [1_100, 1_118, 1_136, 1_154])
    }

    func test_tick_clampsSoilAtDriestValue() {
        let (sut, schedule) = makeSUT()
        let packets = subscribe(sut)

        schedule.tick(times: 200)

        XCTAssertEqual(packets().last?.soilMillivolts, 2_600)
    }

    func test_water_resetsSoilToWetFromNextReading() {
        let (sut, schedule) = makeSUT()
        let packets = subscribe(sut)
        schedule.tick(times: 10)

        sut.water()
        schedule.tick()

        XCTAssertEqual(packets().last?.soilMillivolts, 1_118)
    }

    func test_tick_followsDayCurveForLight() {
        // Starts at 08:00, one simulated hour per tick.
        let (sut, schedule) = makeSUT()
        let packets = subscribe(sut)

        schedule.tick(times: 23)

        let luxByHour = Dictionary(uniqueKeysWithValues: packets().enumerated().map { ((8 + $0.offset) % 24, $0.element.lux) })
        XCTAssertEqual(luxByHour[8], 1_000)    // sin(π/6) of the 2,000 lx peak
        XCTAssertEqual(luxByHour[12], 2_000)   // noon peak
        XCTAssertEqual(luxByHour[18], 0)       // sunset
        XCTAssertEqual(luxByHour[0], 0)        // night
        XCTAssertEqual(luxByHour[5], 0)
        XCTAssertGreaterThan(luxByHour[7] ?? 0, 0)
    }

    func test_tick_variesTemperatureAndHumidityWithinSmallRange() {
        let (sut, schedule) = makeSUT()
        let packets = subscribe(sut)

        schedule.tick(times: 24)

        let temperatures = packets().map(\.temperatureCenti)
        let humidities = packets().map(\.humidityCenti)
        XCTAssertEqual(temperatures.min(), 1_900)
        XCTAssertEqual(temperatures.max(), 2_300)
        XCTAssertEqual(humidities.min(), 4_500)
        XCTAssertEqual(humidities.max(), 5_500)
    }

    func test_init_startsSimulatedClockAtStartDate() {
        let (sut, _) = makeSUT(startDate: morningDate())

        XCTAssertEqual(sut.currentDate, morningDate())
    }

    func test_tick_advancesSimulatedClockByTickIntervalTimesTimeScale() {
        let (sut, schedule) = makeSUT(tickInterval: 2, timeScale: 720)
        _ = subscribe(sut)

        schedule.tick(times: 3)

        XCTAssertEqual(sut.currentDate, morningDate().addingTimeInterval(3 * 2 * 720))
    }

    func test_read_doesNotAdvanceSimulatedClock() {
        let (sut, _) = makeSUT()

        _ = read(sut)

        XCTAssertEqual(sut.currentDate, morningDate())
    }

    func test_makePacket_usesCalendarTimeZoneForDayCurve() {
        // 08:00 UTC is 12:00 in UTC+4, so the light is at its noon peak there.
        var plusFour = utcCalendar()
        plusFour.timeZone = TimeZone(secondsFromGMT: 4 * 3_600)!
        let (sut, _) = makeSUT(calendar: plusFour)

        XCTAssertEqual(read(sut)?.lux, 2_000)
    }

    func test_defaultStartDate_isEightInTheMorningOfGivenDay() {
        let now = morningDate().addingTimeInterval(5 * 3_600 + 123)

        let start = SimulatedPeripheralClient.defaultStartDate(now: now, calendar: utcCalendar())

        XCTAssertEqual(start, morningDate())
    }

    func test_write_deliversUnsupportedCharacteristicError() {
        let (sut, _) = makeSUT()

        var received: Error?
        sut.write(Data([0x01]), to: .command) { received = $0 }

        XCTAssertEqual(received as? SimulatedPeripheralClient.Error, .unsupportedCharacteristic)
    }

    func test_tick_keepsScheduleRunningWhileClientIsAlive() {
        let (sut, schedule) = makeSUT()
        _ = subscribe(sut)

        XCTAssertTrue(schedule.tick())
    }

    func test_tick_stopsScheduleAfterClientIsReleased() {
        let schedule = ScheduleSpy()
        var sut: SimulatedPeripheralClient? = SimulatedPeripheralClient(schedule: schedule.schedule)
        sut?.subscribe(to: .readings) { _ in }

        sut = nil

        XCTAssertFalse(schedule.tick(), "Expected the schedule to stop once the client is released")
    }

    func test_subscribe_doesNotCreateMemoryLeaks() {
        let schedule = ScheduleSpy()
        var sut: SimulatedPeripheralClient? = SimulatedPeripheralClient(schedule: schedule.schedule)
        weak let weakSUT = sut

        sut?.subscribe(to: .readings) { _ in }

        sut = nil
        XCTAssertNil(weakSUT, "Expect the pending schedule not to keep the client alive")
    }

    func test_repeatingTimer_invalidatesWhenTickReturnsFalse() {
        let counter = Counter()
        let exp = expectation(description: "wait for last tick")

        SimulatedPeripheralClient.repeatingTimer(interval: 0.01) {
            counter.value += 1
            guard counter.value < 3 else {
                exp.fulfill()
                return false
            }
            return true
        }
        wait(for: [exp], timeout: 1.0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        XCTAssertEqual(counter.value, 3, "Expected no ticks after the timer was invalidated")
    }

    // MARK: - Private helpers

    private func makeSUT(
        tickInterval: TimeInterval = 1,
        timeScale: Double = 3_600,
        startDate: Date? = nil,
        calendar: Calendar? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: SimulatedPeripheralClient, schedule: ScheduleSpy) {
        let schedule = ScheduleSpy()
        let sut = SimulatedPeripheralClient(
            tickInterval: tickInterval,
            timeScale: timeScale,
            startDate: startDate ?? morningDate(),
            calendar: calendar ?? utcCalendar(),
            schedule: schedule.schedule
        )
        trackMemoryLeak(schedule, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, schedule)
    }

    private func read(_ sut: SimulatedPeripheralClient, file: StaticString = #filePath, line: UInt = #line) -> ReadingPacket? {
        var packet: ReadingPacket?
        sut.read(.readings) { result in
            switch result {
            case .success(let data):
                packet = self.decode(data, file: file, line: line)
            case .failure(let error):
                XCTFail("Expected a packet, got \(error) instead", file: file, line: line)
            }
        }
        return packet
    }

    /// Subscribes to readings and returns a closure giving every packet received so far.
    private func subscribe(_ sut: SimulatedPeripheralClient, file: StaticString = #filePath, line: UInt = #line) -> () -> [ReadingPacket] {
        let collector = PacketCollector()
        sut.subscribe(to: .readings) { [weak self] result in
            switch result {
            case .success(let data):
                if let packet = self?.decode(data, file: file, line: line) {
                    collector.packets.append(packet)
                }
            case .failure(let error):
                XCTFail("Expected a packet, got \(error) instead", file: file, line: line)
            }
        }
        return { collector.packets }
    }

    private func assertUnsupported(
        _ result: PeripheralClient.Result?,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch result {
        case .failure(let error as SimulatedPeripheralClient.Error):
            XCTAssertEqual(error, .unsupportedCharacteristic, message, file: file, line: line)
        default:
            XCTFail("Expected unsupportedCharacteristic, got \(String(describing: result)) instead. \(message)", file: file, line: line)
        }
    }

    @MainActor
    private final class PacketCollector {
        var packets: [ReadingPacket] = []
    }

    @MainActor
    private final class Counter {
        var value = 0
    }
}
