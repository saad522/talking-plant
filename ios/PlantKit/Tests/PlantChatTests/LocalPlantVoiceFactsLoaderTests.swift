import PlantShared
import XCTest
@testable import PlantChat

@MainActor
final class LocalPlantVoiceFactsLoaderTests: PlantChatXCTestCase {
    func test_init_doesNotMessageCollaborators() {
        let (_, moodLoader, store) = makeSUT()

        XCTAssertEqual(moodLoader.messages, [])
        XCTAssertEqual(store.messages, [])
    }

    func test_load_loadsMoodBeforeStore() {
        let (sut, moodLoader, store) = makeSUT()

        sut.load { _ in }

        XCTAssertEqual(moodLoader.messages, [.loadMood])
        XCTAssertEqual(store.messages, [])
    }

    func test_load_retrievesLast24HoursFromStore() {
        let now = anyDate()
        let (sut, moodLoader, store) = makeSUT(currentDate: now)

        sut.load { _ in }
        moodLoader.completeLoad(with: .happy)

        XCTAssertEqual(store.messages, [.retrieve(from: now.addingTimeInterval(-86_400), to: now)])
    }

    func test_load_deliversLatestReadingOfStore() {
        let (sut, moodLoader, store) = makeSUT()
        let older = makeReading(sequence: 1)
        let latest = makeReading(sequence: 2)

        expect(sut, toDeliver: .success(PlantVoiceFacts(mood: .thirsty, isSleeping: false, reading: latest)), when: {
            moodLoader.completeLoad(with: .thirsty)
            store.completeRetrieval(with: [older, latest])
        })
    }

    func test_load_deliversFactsWithoutReadingWhenStoreIsEmpty() {
        let (sut, moodLoader, store) = makeSUT()

        expect(sut, toDeliver: .success(PlantVoiceFacts(mood: .offline, isSleeping: false, reading: nil)), when: {
            moodLoader.completeLoad(with: .offline)
            store.completeRetrieval(with: [])
        })
    }

    func test_load_isSleepingWhenHappyAndDark() {
        let (sut, moodLoader, store) = makeSUT()
        let dark = makeReading(lux: 9)

        expect(sut, toDeliver: .success(PlantVoiceFacts(mood: .happy, isSleeping: true, reading: dark)), when: {
            moodLoader.completeLoad(with: .happy)
            store.completeRetrieval(with: [dark])
        })
    }

    func test_load_isNotSleepingWhenBrightOrNotHappy() {
        let cases: [(PlantMood, Int?)] = [(.happy, 10), (.happy, 1_000), (.happy, nil), (.thirsty, 2), (.offline, 0)]

        cases.forEach { mood, lux in
            let (sut, moodLoader, store) = makeSUT()
            let reading = makeReading(lux: lux)

            expect(sut, toDeliver: .success(PlantVoiceFacts(mood: mood, isSleeping: false, reading: reading)), when: {
                moodLoader.completeLoad(with: mood)
                store.completeRetrieval(with: [reading])
            })
        }
    }

    func test_load_deliversEveryProblemOfMoodState() {
        let (sut, moodLoader, store) = makeSUT()
        let reading = makeReading()

        expect(sut, toDeliver: .success(PlantVoiceFacts(mood: .tooHot, isSleeping: false, reading: reading, problems: [.tooHot, .thirsty])), when: {
            moodLoader.completeLoad(with: .tooHot, problems: [.tooHot, .thirsty])
            store.completeRetrieval(with: [reading])
        })
    }

    // MARK: - Time of day

    func test_load_deliversTimeOfDayFromTheInjectedClock() {
        let hours: [(Int, PlantTimeOfDay)] = [(8, .morning), (13, .afternoon), (19, .evening), (23, .night)]

        hours.forEach { hour, expected in
            let now = Date(timeIntervalSince1970: TimeInterval(hour * 3_600 + 60))
            let (sut, moodLoader, store) = makeSUT(currentDate: now)
            var received: [PlantVoiceFactsLoader.Result] = []

            sut.load { received.append($0) }
            moodLoader.completeLoad(with: .happy)
            store.completeRetrieval(with: [])

            XCTAssertEqual(try? received.first?.get().timeOfDay, expected, "hour \(hour)")
        }
    }

    // MARK: - Recent watering

    func test_load_setsWateredMinutesAgoWhenMoistureRoseMoreThanTwentyPointsInLastHour() {
        let now = anyDate()
        let (sut, moodLoader, store) = makeSUT(currentDate: now)
        let before = makeReading(moisture: 30, receivedAt: now.addingTimeInterval(-25 * 60))
        let after = makeReading(moisture: 51, receivedAt: now.addingTimeInterval(-5 * 60))

        expect(sut, toDeliver: .success(PlantVoiceFacts(mood: .happy, isSleeping: false, reading: after, wateredMinutesAgo: 25)), when: {
            moodLoader.completeLoad(with: .happy)
            store.completeRetrieval(with: [before, after])
        })
    }

    func test_load_doesNotSetWateredMinutesAgoForRiseOfExactlyTwentyPoints() {
        let now = anyDate()
        let (sut, moodLoader, store) = makeSUT(currentDate: now)
        let before = makeReading(moisture: 30, receivedAt: now.addingTimeInterval(-25 * 60))
        let after = makeReading(moisture: 50, receivedAt: now.addingTimeInterval(-5 * 60))

        expect(sut, toDeliver: .success(PlantVoiceFacts(mood: .happy, isSleeping: false, reading: after)), when: {
            moodLoader.completeLoad(with: .happy)
            store.completeRetrieval(with: [before, after])
        })
    }

    func test_load_doesNotSetWateredMinutesAgoWhenRiseStartedMoreThanAnHourAgo() {
        let now = anyDate()
        let (sut, moodLoader, store) = makeSUT(currentDate: now)
        let before = makeReading(moisture: 20, receivedAt: now.addingTimeInterval(-61 * 60))
        let after = makeReading(moisture: 60, receivedAt: now.addingTimeInterval(-30 * 60))
        let latest = makeReading(moisture: 60, receivedAt: now.addingTimeInterval(-1 * 60))

        expect(sut, toDeliver: .success(PlantVoiceFacts(mood: .happy, isSleeping: false, reading: latest)), when: {
            moodLoader.completeLoad(with: .happy)
            store.completeRetrieval(with: [before, after, latest])
        })
    }

    func test_load_skipsReadingsWithoutMoistureWhenLookingForWatering() {
        let now = anyDate()
        let (sut, moodLoader, store) = makeSUT(currentDate: now)
        let before = makeReading(moisture: 30, receivedAt: now.addingTimeInterval(-40 * 60))
        let noMoisture = makeReading(moisture: nil, receivedAt: now.addingTimeInterval(-20 * 60))
        let after = makeReading(moisture: 40, receivedAt: now.addingTimeInterval(-1 * 60))
        let onlyMissing = makeReading(moisture: nil, receivedAt: now)

        expect(sut, toDeliver: .success(PlantVoiceFacts(mood: .happy, isSleeping: false, reading: onlyMissing)), when: {
            moodLoader.completeLoad(with: .happy)
            store.completeRetrieval(with: [before, noMoisture, after, onlyMissing])
        })
    }

    func test_load_deliversRetrievalErrorOnMoodFailure() {
        let (sut, moodLoader, store) = makeSUT()

        expect(sut, toDeliver: .failure(LocalPlantVoiceFactsLoader.Error.retrieval), when: {
            moodLoader.completeLoad(with: anyNSError())
        })
        XCTAssertEqual(store.messages, [])
    }

    func test_load_deliversRetrievalErrorOnStoreFailure() {
        let (sut, moodLoader, store) = makeSUT()

        expect(sut, toDeliver: .failure(LocalPlantVoiceFactsLoader.Error.retrieval), when: {
            moodLoader.completeLoad(with: .happy)
            store.completeRetrieval(with: anyNSError())
        })
    }

    func test_subscribe_forwardsToMoodLoader() {
        let (sut, moodLoader, _) = makeSUT()
        var updates = 0

        sut.subscribe { updates += 1 }
        moodLoader.simulateUpdate()
        moodLoader.simulateUpdate()

        XCTAssertEqual(moodLoader.messages, [.subscribeMood])
        XCTAssertEqual(updates, 2)
    }

    func test_load_doesNotCreateMemoryLeaks() {
        let moodLoader = MoodLoaderStub()
        let store = StoreSpy()
        var sut: LocalPlantVoiceFactsLoader? = LocalPlantVoiceFactsLoader(moodLoader: moodLoader, store: store)
        weak var weakSUT = sut

        sut?.load { _ in }
        sut = nil

        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    func test_subscribe_doesNotCreateMemoryLeaks() {
        let moodLoader = MoodLoaderStub()
        var sut: LocalPlantVoiceFactsLoader? = LocalPlantVoiceFactsLoader(moodLoader: moodLoader, store: StoreSpy())
        weak var weakSUT = sut

        sut?.subscribe {}
        sut = nil

        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(
        currentDate: Date? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LocalPlantVoiceFactsLoader, moodLoader: MoodLoaderStub, store: StoreSpy) {
        let moodLoader = MoodLoaderStub()
        let store = StoreSpy()
        let now = currentDate ?? anyDate()
        let sut = LocalPlantVoiceFactsLoader(moodLoader: moodLoader, store: store, currentDate: { now }, calendar: utcCalendar)
        trackMemoryLeak(moodLoader, file: file, line: line)
        trackMemoryLeak(store, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, moodLoader, store)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Time of day has its own tests.
    private func withoutTimeOfDay(_ facts: PlantVoiceFacts) -> PlantVoiceFacts {
        PlantVoiceFacts(
            mood: facts.mood,
            isSleeping: facts.isSleeping,
            reading: facts.reading,
            problems: facts.problems,
            wateredMinutesAgo: facts.wateredMinutesAgo
        )
    }

    private func expect(
        _ sut: LocalPlantVoiceFactsLoader,
        toDeliver expected: PlantVoiceFactsLoader.Result,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var received: [PlantVoiceFactsLoader.Result] = []
        sut.load { received.append($0) }

        action()

        guard received.count == 1 else {
            return XCTFail("Expected one result, got \(received.count)", file: file, line: line)
        }
        switch (expected, received[0]) {
        case let (.success(expected), .success(received)):
            XCTAssertEqual(expected, withoutTimeOfDay(received), file: file, line: line)
        case let (.failure(expected as LocalPlantVoiceFactsLoader.Error), .failure(received as LocalPlantVoiceFactsLoader.Error)):
            XCTAssertEqual(expected, received, file: file, line: line)
        default:
            XCTFail("Expected \(expected), got \(received[0]) instead", file: file, line: line)
        }
    }
}
