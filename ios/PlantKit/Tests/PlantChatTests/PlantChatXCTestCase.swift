import PlantShared
import XCTest
@testable import PlantChat

@MainActor
class PlantChatXCTestCase: XCTestCase {
    func anyNSError() -> NSError {
        NSError(domain: "any", code: 1)
    }

    func anyDate() -> Date {
        Date(timeIntervalSince1970: 1_000_000)
    }

    func makeReading(
        moisture: Double? = 50,
        lux: Int? = 1_000,
        temperature: Double? = 23.5,
        humidity: Double? = 55.2,
        batteryMillivolts: Int? = nil,
        sequence: UInt32 = 42,
        receivedAt: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> PlantReading {
        PlantReading(
            moisture: moisture,
            lux: lux,
            temperature: temperature,
            humidity: humidity,
            batteryMillivolts: batteryMillivolts,
            sequence: sequence,
            receivedAt: receivedAt
        )
    }

    func makeFacts(
        mood: PlantMood = .thirsty,
        isSleeping: Bool = false,
        reading: PlantReading? = nil,
        problems: [PlantMood] = [],
        wateredMinutesAgo: Int? = nil
    ) -> PlantVoiceFacts {
        PlantVoiceFacts(
            mood: mood,
            isSleeping: isSleeping,
            reading: reading ?? makeReading(),
            problems: problems,
            wateredMinutesAgo: wateredMinutesAgo
        )
    }

    func trackMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be deallocated. Potential memory leak", file: file, line: line)
        }
    }

    @MainActor
    final class LanguageModelClientSpy: PlantLanguageModelClient {
        struct Message: Equatable {
            let instructions: String
            let canReadHistory: Bool
        }

        var isAvailable: Bool = true
        private(set) var messages: [Message] = []
        private(set) var sessions: [SessionSpy] = []

        func makeSession(instructions: String, canReadHistory: Bool) -> PlantLanguageModelSession {
            messages.append(Message(instructions: instructions, canReadHistory: canReadHistory))
            let session = SessionSpy()
            sessions.append(session)
            return session
        }
    }

    @MainActor
    final class SessionSpy: PlantLanguageModelSession {
        private(set) var prompts: [String] = []

        private var completions: [(PlantLanguageModelSession.Result) -> Void] = []
        func respond(to prompt: String, completion: @escaping (PlantLanguageModelSession.Result) -> Void) {
            prompts.append(prompt)
            completions.append(completion)
        }

        func complete(with text: String, at index: Int = 0) {
            completions[index](.success(text))
        }

        func complete(with error: Error, at index: Int = 0) {
            completions[index](.failure(error))
        }
    }

    @MainActor
    final class MoodLoaderStub: PlantMoodLoader {
        enum Message: Equatable {
            case loadMood
            case subscribeMood
        }

        var messages: [Message] = []

        private var loadCompletions: [(PlantMoodLoader.Result) -> Void] = []
        func load(completion: @escaping (PlantMoodLoader.Result) -> Void) {
            messages.append(.loadMood)
            loadCompletions.append(completion)
        }

        func completeLoad(with mood: PlantMood, problems: [PlantMood] = [], at index: Int = 0) {
            loadCompletions[index](.success(PlantMoodState(mood: mood, problems: problems)))
        }

        func completeLoad(with error: Error, at index: Int = 0) {
            loadCompletions[index](.failure(error))
        }

        private var subscriptions: [() -> Void] = []
        func subscribe(update: @escaping () -> Void) {
            messages.append(.subscribeMood)
            subscriptions.append(update)
        }

        func simulateUpdate(at index: Int = 0) {
            subscriptions[index]()
        }
    }

    @MainActor
    final class StoreSpy: PlantReadingStore {
        enum Message: Equatable {
            case insert(PlantReading)
            case retrieve(from: Date, to: Date)
            case subscribe
        }

        var messages: [Message] = []

        private var insertCompletions: [(PlantReadingStore.InsertionResult) -> Void] = []
        func insert(_ reading: PlantReading, completion: @escaping (PlantReadingStore.InsertionResult) -> Void) {
            messages.append(.insert(reading))
            insertCompletions.append(completion)
        }

        private var retrievalCompletions: [(PlantReadingStore.RetrievalResult) -> Void] = []
        func retrieve(from start: Date, to end: Date, completion: @escaping (PlantReadingStore.RetrievalResult) -> Void) {
            messages.append(.retrieve(from: start, to: end))
            retrievalCompletions.append(completion)
        }

        func completeRetrieval(with readings: [PlantReading], at index: Int = 0) {
            retrievalCompletions[index](.success(readings))
        }

        func completeRetrieval(with error: Error, at index: Int = 0) {
            retrievalCompletions[index](.failure(error))
        }

        private var subscriptions: [() -> Void] = []
        func subscribe(update: @escaping () -> Void) {
            messages.append(.subscribe)
            subscriptions.append(update)
        }

        func simulateInsertion(at index: Int = 0) {
            subscriptions[index]()
        }
    }

    @MainActor
    final class DefaultsSpy: DefaultsClient {
        enum Message: Equatable {
            case set(Double, forKey: String)
            case retrieve(forKey: String)
            case setString(String, forKey: String)
            case retrieveString(forKey: String)
        }

        private(set) var messages: [Message] = []
        private var doubles: [String: Double] = [:]
        private var strings: [String: String] = [:]

        func stub(_ value: Double, forKey key: String) {
            doubles[key] = value
        }

        func stub(_ value: String, forKey key: String) {
            strings[key] = value
        }

        func set(_ value: Double, forKey key: String) {
            messages.append(.set(value, forKey: key))
            doubles[key] = value
        }

        func retrieve(forKey key: String) -> Double? {
            messages.append(.retrieve(forKey: key))
            return doubles[key]
        }

        func set(_ value: String, forKey key: String) {
            messages.append(.setString(value, forKey: key))
            strings[key] = value
        }

        func retrieveString(forKey key: String) -> String? {
            messages.append(.retrieveString(forKey: key))
            return strings[key]
        }
    }

    @MainActor
    final class NotificationClientSpy: PlantNotificationClient {
        struct Post: Equatable {
            let title: String
            let body: String
        }

        private(set) var posts: [Post] = []

        func post(title: String, body: String) {
            posts.append(Post(title: title, body: body))
        }
    }

    @MainActor
    final class FactsLoaderStub: PlantVoiceFactsLoader {
        enum Message: Equatable {
            case loadFacts
            case subscribeFacts
        }

        var messages: [Message] = []

        private var loadCompletions: [(PlantVoiceFactsLoader.Result) -> Void] = []
        func load(completion: @escaping (PlantVoiceFactsLoader.Result) -> Void) {
            messages.append(.loadFacts)
            loadCompletions.append(completion)
        }

        func completeLoad(with facts: PlantVoiceFacts, at index: Int = 0) {
            loadCompletions[index](.success(facts))
        }

        func completeLoad(with error: Error, at index: Int = 0) {
            loadCompletions[index](.failure(error))
        }

        private var subscriptions: [() -> Void] = []
        func subscribe(update: @escaping () -> Void) {
            messages.append(.subscribeFacts)
            subscriptions.append(update)
        }

        func simulateUpdate(at index: Int = 0) {
            subscriptions[index]()
        }
    }

    @MainActor
    final class LineLoaderStub: PlantVoiceLineLoader {
        private(set) var requests: [PlantVoiceLineRequest] = []

        private var completions: [(PlantVoiceLineLoader.Result) -> Void] = []
        func load(_ request: PlantVoiceLineRequest, completion: @escaping (PlantVoiceLineLoader.Result) -> Void) {
            requests.append(request)
            completions.append(completion)
        }

        func complete(with line: String, at index: Int = 0) {
            completions[index](.success(line))
        }

        func complete(with error: Error, at index: Int = 0) {
            completions[index](.failure(error))
        }
    }

    @MainActor
    final class ChatLoaderStub: PlantChatLoader {
        struct Send: Equatable {
            let text: String
            let facts: PlantVoiceFacts
        }

        var isAvailable: Bool = true
        private(set) var sends: [Send] = []
        private(set) var resetCount = 0

        private var completions: [(PlantChatLoader.Result) -> Void] = []
        func send(_ text: String, facts: PlantVoiceFacts, completion: @escaping (PlantChatLoader.Result) -> Void) {
            sends.append(Send(text: text, facts: facts))
            completions.append(completion)
        }

        func reset() {
            resetCount += 1
        }

        func complete(with reply: String, at index: Int = 0) {
            completions[index](.success(reply))
        }

        func complete(with error: Error, at index: Int = 0) {
            completions[index](.failure(error))
        }
    }
}
