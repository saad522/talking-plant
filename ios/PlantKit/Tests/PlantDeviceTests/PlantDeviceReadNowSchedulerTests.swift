import PlantShared
import XCTest
@testable import PlantDevice

@MainActor
final class PlantDeviceReadNowSchedulerTests: PlantDeviceXCTestCase {
    func test_init_doesNotSendOrSchedule() {
        let (_, commands, schedule) = makeSUT()

        XCTAssertEqual(commands.commands, [])
        XCTAssertEqual(schedule.intervals, [])
    }

    func test_scheduleReadNow_schedulesAfterDelayWithoutSendingYet() {
        let (sut, commands, schedule) = makeSUT(delay: 10)

        sut.scheduleReadNow()

        XCTAssertEqual(schedule.intervals, [10])
        XCTAssertEqual(commands.commands, [])
    }

    func test_scheduleReadNow_sendsReadNowOnTickOnce() {
        let (sut, commands, schedule) = makeSUT()
        sut.scheduleReadNow()

        let repeats = schedule.fire()

        XCTAssertFalse(repeats)
        XCTAssertEqual(commands.commands, [.readNow])
    }

    func test_scheduleReadNow_onlyLatestRequestSends() {
        let (sut, commands, schedule) = makeSUT()
        sut.scheduleReadNow()
        sut.scheduleReadNow()

        schedule.fire(at: 0)
        XCTAssertEqual(commands.commands, [])

        schedule.fire(at: 1)
        XCTAssertEqual(commands.commands, [.readNow])
    }

    func test_scheduleReadNow_doesNotSendAfterDeallocation() {
        let commands = CommandSenderStub()
        let schedule = ScheduleSpy()
        var sut: PlantDeviceReadNowScheduler? = PlantDeviceReadNowScheduler(commands: commands, schedule: schedule.schedule)
        sut?.scheduleReadNow()

        sut = nil
        schedule.fire()

        XCTAssertEqual(commands.commands, [])
    }

    // MARK: - Private helpers

    private func makeSUT(
        delay: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantDeviceReadNowScheduler, commands: CommandSenderStub, schedule: ScheduleSpy) {
        let commands = CommandSenderStub()
        let schedule = ScheduleSpy()
        let sut = PlantDeviceReadNowScheduler(commands: commands, delay: delay, schedule: schedule.schedule)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, commands, schedule)
    }
}
