import PlantShared
import XCTest
@testable import PlantChat

@MainActor
final class PlantMoodNotifierTests: PlantChatXCTestCase {
    private func key(_ mood: PlantMood) -> String { "plant.chat.notification.lastDate.\(mood)" }

    func test_init_doesNotMessageCollaborators() {
        let sut = makeSUT()

        XCTAssertEqual(sut.factsLoader.messages, [])
        XCTAssertEqual(sut.lineLoader.requests, [])
        XCTAssertEqual(sut.notifications.posts, [])
        XCTAssertEqual(sut.defaults.messages, [])
    }

    func test_start_subscribesToFactsThenLoadsFacts() {
        let sut = makeSUT()

        sut.notifier.start()

        XCTAssertEqual(sut.factsLoader.messages, [.subscribeFacts, .loadFacts])
    }

    func test_firstMood_isOnlyRecorded() {
        let sut = makeSUT()

        sut.notifier.start()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .veryThirsty))

        XCTAssertEqual(sut.lineLoader.requests, [])
        XCTAssertEqual(sut.notifications.posts, [])
        XCTAssertEqual(sut.defaults.messages, [])
    }

    func test_moodChangeToProblem_loadsNotificationLine() {
        let sut = makeSUT()
        let problem = makeFacts(mood: .tooHot)

        sut.changeMood(from: makeFacts(mood: .happy), to: problem)

        XCTAssertEqual(sut.lineLoader.requests, [PlantVoiceLineRequest(facts: problem, purpose: .notification)])
    }

    func test_moodChangeToProblem_postsGeneratedLineTitledWithPlantName() {
        let sut = makeSUT(plantName: "Sprout")

        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .thirsty))
        sut.lineLoader.complete(with: "Psst, I'm thirsty.")

        XCTAssertEqual(sut.notifications.posts, [.init(title: "Sprout", body: "Psst, I'm thirsty.")])
    }

    func test_moodChangeToProblem_postsTemplateLineWhenGenerationFails() {
        let sut = makeSUT()

        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .veryThirsty))
        sut.lineLoader.complete(with: anyNSError())

        XCTAssertEqual(sut.notifications.posts, [.init(title: "Sprout", body: String.localised(key: "plant.chat.mood.veryThirsty.speech"))])
    }

    func test_everyProblemMood_hasItsOwnTemplate() {
        let problems = PlantMood.allCases.filter { $0 != .happy }

        let bodies = problems.map { mood -> String in
            let sut = makeSUT()
            sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: mood))
            sut.lineLoader.complete(with: anyNSError())
            return sut.notifications.posts[0].body
        }

        XCTAssertEqual(Set(bodies).count, problems.count)
    }

    func test_moodChangeToHappy_doesNotNotify() {
        let sut = makeSUT()

        sut.changeMood(from: makeFacts(mood: .thirsty), to: makeFacts(mood: .happy))

        XCTAssertEqual(sut.lineLoader.requests, [])
        XCTAssertEqual(sut.notifications.posts, [])
    }

    func test_unchangedMood_doesNotNotify() {
        let sut = makeSUT()

        sut.changeMood(from: makeFacts(mood: .thirsty), to: makeFacts(mood: .thirsty))

        XCTAssertEqual(sut.lineLoader.requests, [])
    }

    func test_factsUpdate_loadsFactsAgain() {
        let sut = makeSUT()

        sut.notifier.start()
        sut.factsLoader.simulateUpdate()

        XCTAssertEqual(sut.factsLoader.messages, [.subscribeFacts, .loadFacts, .loadFacts])
    }

    func test_factsLoadFailure_doesNotNotifyOrForgetMood() {
        let sut = makeSUT()

        sut.notifier.start()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .happy))
        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: anyNSError(), at: 1)
        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .thirsty), at: 2)

        XCTAssertEqual(sut.lineLoader.requests.count, 1)
    }

    // MARK: - Rate limit

    func test_notification_savesDateUnderKey() {
        let now = anyDate()
        let sut = makeSUT(now: { now })

        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .thirsty))

        XCTAssertTrue(sut.defaults.messages.contains(.set(now.timeIntervalSince1970, forKey: key(.thirsty))))
    }

    func test_sameMoodInsideInterval_doesNotNotify() {
        var now = anyDate()
        let sut = makeSUT(now: { now })
        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .thirsty))

        now = now.addingTimeInterval(3_599)
        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .happy), at: 2)
        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .thirsty), at: 3)

        XCTAssertEqual(sut.lineLoader.requests.count, 1)
    }

    func test_sameMoodAtAndAfterInterval_notifiesAgain() {
        var now = anyDate()
        let sut = makeSUT(now: { now })
        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .thirsty))

        now = now.addingTimeInterval(3_600)
        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .happy), at: 2)
        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .thirsty), at: 3)

        XCTAssertEqual(sut.lineLoader.requests.count, 2)
    }

    func test_escalationInsideInterval_notifies() {
        let now = anyDate()
        let sut = makeSUT(now: { now })
        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .thirsty))

        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .veryThirsty), at: 2)

        XCTAssertEqual(sut.lineLoader.requests.count, 2)
        XCTAssertTrue(sut.defaults.messages.contains(.set(now.timeIntervalSince1970, forKey: key(.veryThirsty))))
    }

    func test_escalation_followsInjectedRanking() {
        let ranking: [PlantMood] = [.thirsty, .veryThirsty]
        let sut = makeSUT(severityRanking: ranking)
        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .veryThirsty))

        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .thirsty), at: 2)
        XCTAssertEqual(sut.lineLoader.requests.count, 2)

        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .veryThirsty), at: 3)
        XCTAssertEqual(sut.lineLoader.requests.count, 2)
    }

    func test_moodMissingFromRanking_isNeverAnEscalation() {
        let sut = makeSUT(severityRanking: [.veryThirsty])
        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .thirsty))

        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .veryThirsty), at: 2)
        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .thirsty), at: 3)

        XCTAssertEqual(sut.lineLoader.requests.count, 2)
    }

    func test_deEscalationToRecentlyNotifiedMood_doesNotNotify() {
        let now = anyDate()
        let sut = makeSUT(now: { now })
        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .thirsty))
        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .veryThirsty), at: 2)

        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .thirsty), at: 3)

        XCTAssertEqual(sut.lineLoader.requests.count, 2)
    }

    func test_differentLessSevereMoodNeverNotified_notifies() {
        let sut = makeSUT()
        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .veryThirsty))

        sut.factsLoader.simulateUpdate()
        sut.factsLoader.completeLoad(with: makeFacts(mood: .dryAir), at: 2)

        XCTAssertEqual(sut.lineLoader.requests.count, 2)
    }

    func test_savedDate_limitsAcrossInstances() {
        let now = anyDate()
        let defaults = DefaultsSpy()
        defaults.stub(now.addingTimeInterval(-60).timeIntervalSince1970, forKey: key(.thirsty))
        let sut = makeSUT(now: { now }, defaults: defaults)

        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .thirsty))

        XCTAssertEqual(sut.lineLoader.requests, [])
    }

    func test_oldSavedDate_doesNotLimit() {
        let now = anyDate()
        let defaults = DefaultsSpy()
        defaults.stub(now.addingTimeInterval(-3_601).timeIntervalSince1970, forKey: key(.thirsty))
        let sut = makeSUT(now: { now }, defaults: defaults)

        sut.changeMood(from: makeFacts(mood: .happy), to: makeFacts(mood: .thirsty))

        XCTAssertEqual(sut.lineLoader.requests.count, 1)
    }

    func test_start_doesNotCreateMemoryLeaks() {
        let factsLoader = FactsLoaderStub()
        var sut: PlantMoodNotifier? = PlantMoodNotifier(
            factsLoader: factsLoader,
            lineLoader: LineLoaderStub(),
            notifications: NotificationClientSpy(),
            defaults: DefaultsSpy(),
            plantName: "Sprout",
            minimumInterval: 3_600,
            severityRanking: Self.severityRanking
        )
        weak var weakSUT = sut

        sut?.start()
        sut = nil

        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private struct SUT {
        let notifier: PlantMoodNotifier
        let factsLoader: FactsLoaderStub
        let lineLoader: LineLoaderStub
        let notifications: NotificationClientSpy
        let defaults: DefaultsSpy

        /// Starts, delivers `first` as the recorded mood, then an update delivering `second`.
        @MainActor
        func changeMood(from first: PlantVoiceFacts, to second: PlantVoiceFacts) {
            notifier.start()
            factsLoader.completeLoad(with: first)
            factsLoader.simulateUpdate()
            factsLoader.completeLoad(with: second, at: 1)
        }
    }

    private static let severityRanking: [PlantMood] = [.offline, .drowning, .veryThirsty, .tooHot, .tooCold, .thirsty, .tooDark, .dryAir]

    private func makeSUT(
        plantName: String = "Sprout",
        severityRanking: [PlantMood] = severityRanking,
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_000_000) },
        defaults: DefaultsSpy = DefaultsSpy(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SUT {
        let factsLoader = FactsLoaderStub()
        let lineLoader = LineLoaderStub()
        let notifications = NotificationClientSpy()
        let notifier = PlantMoodNotifier(
            factsLoader: factsLoader,
            lineLoader: lineLoader,
            notifications: notifications,
            defaults: defaults,
            plantName: plantName,
            currentDate: now,
            minimumInterval: 3_600,
            severityRanking: severityRanking
        )
        trackMemoryLeak(factsLoader, file: file, line: line)
        trackMemoryLeak(lineLoader, file: file, line: line)
        trackMemoryLeak(notifications, file: file, line: line)
        trackMemoryLeak(defaults, file: file, line: line)
        trackMemoryLeak(notifier, file: file, line: line)
        return SUT(notifier: notifier, factsLoader: factsLoader, lineLoader: lineLoader, notifications: notifications, defaults: defaults)
    }
}
