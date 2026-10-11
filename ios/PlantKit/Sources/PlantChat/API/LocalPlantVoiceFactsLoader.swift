import Foundation
import PlantShared

@MainActor
public final class LocalPlantVoiceFactsLoader: PlantVoiceFactsLoader {
    /// Below this light level (lux) it's night. Same threshold as the home scene.
    static let nightLux = 10
    static let window: TimeInterval = 24 * 60 * 60
    /// Watering is looked for in this part of the window.
    static let wateringWindow: TimeInterval = 60 * 60
    /// Moisture must rise by more than this many points to count as watering.
    static let wateringRise = 20.0

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
            case .success(let state):
                let now = currentDate()
                store.retrieve(from: now.addingTimeInterval(-Self.window), to: now) { result in
                    switch result {
                    case .success(let readings):
                        completion(.success(Self.facts(state: state, readings: readings, now: now)))
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

    private static func facts(state: PlantMoodState, readings: [PlantReading], now: Date) -> PlantVoiceFacts {
        let reading = readings.last
        let isDark = reading?.lux.map { $0 < nightLux } ?? false
        return PlantVoiceFacts(
            mood: state.mood,
            isSleeping: state.mood == .happy && isDark,
            reading: reading,
            problems: state.problems,
            wateredMinutesAgo: wateredMinutesAgo(in: readings, now: now)
        )
    }

    /// Minutes since the first reading of a moisture rise of more than `wateringRise` points
    /// within the last hour, or nil when there was none.
    private static func wateredMinutesAgo(in readings: [PlantReading], now: Date) -> Int? {
        let recent = readings
            .filter { $0.receivedAt >= now.addingTimeInterval(-wateringWindow) }
            .compactMap { reading in reading.moisture.map { (date: reading.receivedAt, moisture: $0) } }
        for (index, start) in recent.enumerated()
        where recent[(index + 1)...].contains(where: { $0.moisture - start.moisture > wateringRise }) {
            return Int(now.timeIntervalSince(start.date) / 60)
        }
        return nil
    }
}
