import PlantChat
import PlantChatiOS
import PlantShared
import SwiftUI
import XCTest

@MainActor
class PlantChatiOSXCTestCase: XCTestCase {
    func makeSUT(
        savedPersonality: PlantPersonality? = nil,
        isAvailable: Bool = true,
        actionHandler: @escaping (PlantChatAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: PlantChatView<FaceStub>,
        chatLoader: ChatLoaderStub,
        lineLoader: LineLoaderStub,
        factsLoader: FactsLoaderStub,
        defaults: DefaultsSpy
    ) {
        let chatLoader = ChatLoaderStub()
        chatLoader.isAvailable = isAvailable
        let lineLoader = LineLoaderStub()
        let factsLoader = FactsLoaderStub()
        let defaults = DefaultsSpy()
        if let savedPersonality {
            defaults.stub(savedPersonality.rawValue, forKey: "plant.chat.personality")
        }
        let sut = PlantChatUIComposer.composed(
            chatLoader: chatLoader,
            lineLoader: lineLoader,
            factsLoader: factsLoader,
            settings: PlantPersonalitySettings(defaults: defaults),
            plantName: "Sprout",
            face: { FaceStub(mood: $0) },
            actionHandler: actionHandler
        )
        trackMemoryLeak(chatLoader, file: file, line: line)
        trackMemoryLeak(lineLoader, file: file, line: line)
        trackMemoryLeak(factsLoader, file: file, line: line)
        trackMemoryLeak(defaults, file: file, line: line)
        return (sut, chatLoader, lineLoader, factsLoader, defaults)
    }

    func anyNSError() -> NSError {
        NSError(domain: "any", code: 1)
    }

    func makeFacts(mood: PlantMood = .thirsty) -> PlantVoiceFacts {
        PlantVoiceFacts(
            mood: mood,
            isSleeping: false,
            reading: PlantReading(
                moisture: 24,
                lux: 1_000,
                temperature: 23.5,
                humidity: 55,
                batteryMillivolts: nil,
                sequence: 1,
                receivedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
    }

    func trackMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be deallocated. Potential memory leak", file: file, line: line)
        }
    }

    @MainActor
    final class DefaultsSpy: DefaultsClient {
        private(set) var savedStrings: [String: String] = [:]

        func stub(_ value: String, forKey key: String) {
            savedStrings[key] = value
        }

        func set(_ value: Double, forKey key: String) {}
        func retrieve(forKey key: String) -> Double? { nil }

        func set(_ value: String, forKey key: String) {
            savedStrings[key] = value
        }

        func retrieveString(forKey key: String) -> String? {
            savedStrings[key]
        }
    }

    @MainActor
    final class FactsLoaderStub: PlantVoiceFactsLoader {
        private var loadCompletions: [(PlantVoiceFactsLoader.Result) -> Void] = []
        func load(completion: @escaping (PlantVoiceFactsLoader.Result) -> Void) {
            loadCompletions.append(completion)
        }

        func completeLoad(with facts: PlantVoiceFacts, at index: Int = 0) {
            loadCompletions[index](.success(facts))
        }

        private var subscriptions: [() -> Void] = []
        func subscribe(update: @escaping () -> Void) {
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
    }

    @MainActor
    final class ChatLoaderStub: PlantChatLoader {
        var isAvailable: Bool = true
        private(set) var sentTexts: [String] = []
        private(set) var resetCount = 0

        private var completions: [(PlantChatLoader.Result) -> Void] = []
        func send(_ text: String, facts: PlantVoiceFacts, completion: @escaping (PlantChatLoader.Result) -> Void) {
            sentTexts.append(text)
            completions.append(completion)
        }

        func reset() {
            resetCount += 1
        }

        func complete(with reply: String, at index: Int = 0) {
            completions[index](.success(reply))
        }
    }
}

struct FaceStub: View, Equatable {
    let mood: PlantMood

    var body: some View {
        Text("face")
    }
}
