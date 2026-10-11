import Foundation
import PlantShared

/// Tells the person when the plant's mood turns into a problem. The same mood is announced at most
/// once per interval; a mood more severe than the previous problem is always announced.
@MainActor
public final class PlantMoodNotifier {
    static func lastDateKey(for mood: PlantMood) -> String {
        "plant.chat.notification.lastDate.\(mood)"
    }

    private let factsLoader: PlantVoiceFactsLoader
    private let lineLoader: PlantVoiceLineLoader
    private let notifications: PlantNotificationClient
    private let defaults: DefaultsClient
    private let plantName: String
    private let currentDate: () -> Date
    private let minimumInterval: TimeInterval
    private let severityRanking: [PlantMood]
    private var lastMood: PlantMood?

    /// - Parameters:
    ///   - currentDate: The real clock, not the simulated one, so the limit holds in simulated mode.
    ///   - minimumInterval: The least time between two notifications of the same mood, kept across launches.
    ///   - severityRanking: Problem moods, most severe first. A mood missing from it counts as least severe.
    public init(
        factsLoader: PlantVoiceFactsLoader,
        lineLoader: PlantVoiceLineLoader,
        notifications: PlantNotificationClient,
        defaults: DefaultsClient,
        plantName: String,
        currentDate: @escaping () -> Date = Date.init,
        minimumInterval: TimeInterval,
        severityRanking: [PlantMood]
    ) {
        self.factsLoader = factsLoader
        self.lineLoader = lineLoader
        self.notifications = notifications
        self.defaults = defaults
        self.plantName = plantName
        self.currentDate = currentDate
        self.minimumInterval = minimumInterval
        self.severityRanking = severityRanking
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
        guard let previous, previous != facts.mood, facts.mood != .happy,
              isEscalation(from: previous, to: facts.mood) || canNotify(facts.mood) else { return }

        defaults.set(currentDate().timeIntervalSince1970, forKey: Self.lastDateKey(for: facts.mood))

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

    private func canNotify(_ mood: PlantMood) -> Bool {
        guard let last = defaults.retrieve(forKey: Self.lastDateKey(for: mood)) else { return true }
        return currentDate().timeIntervalSince(Date(timeIntervalSince1970: last)) >= minimumInterval
    }

    private func isEscalation(from previous: PlantMood, to mood: PlantMood) -> Bool {
        previous != .happy && severity(of: mood) > severity(of: previous)
    }

    /// Higher is more severe; a mood missing from the ranking is lowest, like happy.
    private func severity(of mood: PlantMood) -> Int {
        guard let index = severityRanking.firstIndex(of: mood) else { return 0 }
        return severityRanking.count - index
    }
}
