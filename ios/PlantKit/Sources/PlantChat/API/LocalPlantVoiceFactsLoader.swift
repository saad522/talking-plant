import Foundation
import PlantShared

@MainActor
public final class LocalPlantVoiceFactsLoader: PlantVoiceFactsLoader {
    /// Below this light level (lux) it's night. Same threshold as the home scene.
    static let nightLux = 10
    static let window: TimeInterval = 24 * 60 * 60

    private let moodLoader: PlantMoodLoader
    private let store: PlantReadingStore
    private let currentDate: () -> Date

    public enum Error: Swift.Error, Equatable {
        case retrieval
    }

    /// - Parameter currentDate: "Now" for the window. Pass the simulated clock in simulated mode.
    public init(
        moodLoader: PlantMoodLoader,
        store: PlantReadingStore,
        currentDate: @escaping () -> Date = Date.init
    ) {
        self.moodLoader = moodLoader
        self.store = store
        self.currentDate = currentDate
    }

    public func load(completion: @escaping (PlantVoiceFactsLoader.Result) -> Void) {
        let store = store
        let currentDate = currentDate
        moodLoader.load { result in
            switch result {
            case .success(let mood):
                let now = currentDate()
                store.retrieve(from: now.addingTimeInterval(-Self.window), to: now) { result in
                    switch result {
                    case .success(let readings):
                        completion(.success(Self.facts(mood: mood, reading: readings.last)))
                    case .failure:
                        completion(.failure(Error.retrieval))
                    }
                }
            case .failure:
                completion(.failure(Error.retrieval))
            }
        }
    }

    public func subscribe(update: @escaping () -> Void) {
        moodLoader.subscribe(update: update)
    }

    private static func facts(mood: PlantMood, reading: PlantReading?) -> PlantVoiceFacts {
        let isDark = reading?.lux.map { $0 < nightLux } ?? false
        return PlantVoiceFacts(mood: mood, isSleeping: mood == .happy && isDark, reading: reading)
    }
}
