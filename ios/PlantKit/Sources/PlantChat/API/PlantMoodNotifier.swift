import Foundation
import PlantShared

/// Tells the person when the plant's mood turns into a problem, at most once per interval.
@MainActor
public final class PlantMoodNotifier {
    static let lastDateKey = "plant.chat.notification.lastDate"

    private let factsLoader: PlantVoiceFactsLoader
    private let lineLoader: PlantVoiceLineLoader
    private let notifications: PlantNotificationClient
    private let defaults: DefaultsClient
    private let plantName: String
    private let currentDate: () -> Date
    private let minimumInterval: TimeInterval
    private var lastMood: PlantMood?

    /// - Parameters:
    ///   - currentDate: The real clock, not the simulated one, so the limit holds in simulated mode.
    ///   - minimumInterval: The least time between two notifications, kept across launches.
    public init(
        factsLoader: PlantVoiceFactsLoader,
        lineLoader: PlantVoiceLineLoader,
        notifications: PlantNotificationClient,
        defaults: DefaultsClient,
        plantName: String,
        currentDate: @escaping () -> Date = Date.init,
        minimumInterval: TimeInterval
    ) {
        self.factsLoader = factsLoader
        self.lineLoader = lineLoader
        self.notifications = notifications
        self.defaults = defaults
        self.plantName = plantName
        self.currentDate = currentDate
        self.minimumInterval = minimumInterval
    }

    public func start() {
        factsLoader.subscribe { [weak self] in
            self?.loadFacts()
        }
        loadFacts()
    }

    private func loadFacts() {
        factsLoader.load { [weak self] result in
            if case .success(let facts) = result {
                self?.handle(facts)
            }
        }
    }

    private func handle(_ facts: PlantVoiceFacts) {
        let previous = lastMood
        lastMood = facts.mood
        guard let previous, previous != facts.mood, facts.mood != .happy, canNotify() else { return }

        defaults.set(currentDate().timeIntervalSince1970, forKey: Self.lastDateKey)

        let notifications = notifications
        let title = plantName
        let template = PlantChatTemplate.speech(mood: facts.mood, isSleeping: false)
        lineLoader.load(PlantVoiceLineRequest(facts: facts, purpose: .notification)) { result in
            switch result {
            case .success(let line):
                notifications.post(title: title, body: line)
            case .failure:
                notifications.post(title: title, body: template)
            }
        }
    }

    private func canNotify() -> Bool {
        guard let last = defaults.retrieve(forKey: Self.lastDateKey) else { return true }
        return currentDate().timeIntervalSince(Date(timeIntervalSince1970: last)) >= minimumInterval
    }
}
