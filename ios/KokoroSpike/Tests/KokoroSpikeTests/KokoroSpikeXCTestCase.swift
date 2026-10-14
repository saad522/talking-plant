import KokoroSpike
import XCTest

@MainActor
class KokoroSpikeXCTestCase: XCTestCase {
    func trackMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be deallocated. Potential memory leak", file: file, line: line)
        }
    }

    func makeMemory(currentMB: UInt64 = 600, peakMB: UInt64 = 800) -> KokoroSpikeMemory {
        KokoroSpikeMemory(currentBytes: currentMB * 1_048_576, peakBytes: peakMB * 1_048_576)
    }

    @MainActor
    final class ClientSpy: KokoroSpikeSynthesizerClient {
        enum Message: Equatable {
            case load
            case speak(KokoroSpikeRequest)
            case stop
        }

        private(set) var messages: [Message] = []
        private var loadCompletions: [(Result<Void, KokoroSpikeLoadError>) -> Void] = []
        private var updates: [(KokoroSpikeEvent) -> Void] = []

        var requests: [KokoroSpikeRequest] {
            messages.compactMap { if case let .speak(request) = $0 { request } else { nil } }
        }

        func load(completion: @escaping (Result<Void, KokoroSpikeLoadError>) -> Void) {
            messages.append(.load)
            loadCompletions.append(completion)
        }

        func speak(_ request: KokoroSpikeRequest, update: @escaping (KokoroSpikeEvent) -> Void) {
            messages.append(.speak(request))
            updates.append(update)
        }

        func stop() {
            messages.append(.stop)
        }

        func completeLoad(with result: Result<Void, KokoroSpikeLoadError> = .success(()), at index: Int = 0) {
            loadCompletions[index](result)
        }

        func send(_ event: KokoroSpikeEvent, at index: Int = 0) {
            updates[index](event)
        }
    }

    /// A clock the test moves by hand.
    final class ClockStub {
        var now: TimeInterval = 100
    }
}
