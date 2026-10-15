import Foundation
import PlantShared

/// Sprout speaking on home: when it talks on its own, and what a tap does (docs/plans/P1-alive.md D7).
@MainActor
public final class PlantMonitorSproutViewModel {
    public static let settleDelay: TimeInterval = 2.5
    public static let minimumGap: TimeInterval = 60

    private let voice: PlantMonitorVoice
    private let spokenLines: PlantSpokenLineStore
    private let isEnabled: () -> Bool
    private let clock: () -> Date
    private let calendar: Calendar
    private let schedule: SimulatedPeripheralClient.Schedule

    private var isVisible = false
    private var isActive = true
    /// True once the settle delay passed with home open. Cleared whenever home closes.
    private var isSettled = false
    /// Tells a settle timer from an older one, so a closed-and-reopened home only trusts the latest.
    private var settleID = 0
    private var gapTimerPending = false
    private var latestLine: PlantMonitorSpokenLine?
    private var lastAutomaticAt: Date?
    private var speaking: Speaking?
    private var speechID = 0

    private struct Speaking {
        let id: Int
        let trigger: PlantMonitorSpeechTrigger
    }

    private var isOpen: Bool { isVisible && isActive }

    public init(
        voice: PlantMonitorVoice,
        spokenLines: PlantSpokenLineStore,
        isEnabled: @escaping () -> Bool,
        clock: @escaping () -> Date,
        calendar: Calendar,
        schedule: @escaping SimulatedPeripheralClient.Schedule
    ) {
        self.voice = voice
        self.spokenLines = spokenLines
        self.isEnabled = isEnabled
        self.clock = clock
        self.calendar = calendar
        self.schedule = schedule
    }

    public func appear() {
        isVisible = true
        homeStateChanged()
    }

    public func disappear() {
        isVisible = false
        homeStateChanged()
    }

    public func setActive(_ isActive: Bool) {
        self.isActive = isActive
        homeStateChanged()
    }

    /// The bubble's final line for the current mood.
    public func lineSettled(_ line: PlantMonitorSpokenLine) {
        latestLine = line
        speakAutomaticallyIfDue()
    }

    public func sproutTap() {
        guard isEnabled(), let line = latestLine else { return }
        switch speaking?.trigger {
        case .tap:
            return
        case .automatic:
            stopSpeaking()
        case nil:
            break
        }
        speak(line, trigger: .tap)
    }

    // MARK: - Private

    /// Opening home waits for the intro and the first mood to pass. Closing it silences Sprout at once.
    private func homeStateChanged() {
        settleID += 1
        isSettled = false
        guard isOpen else { return stopSpeaking() }
        let id = settleID
        schedule(Self.settleDelay) { [weak self] in
            guard let self, self.settleID == id else { return false }
            self.isSettled = true
            self.speakAutomaticallyIfDue()
            return false
        }
    }

    private func speakAutomaticallyIfDue() {
        guard isOpen, isSettled, speaking == nil, isEnabled(), let line = latestLine else { return }
        let now = clock()
        let today = PlantSpokenLineStore.day(for: now, calendar: calendar)
        guard PlantMonitorSpeechPolicy.shouldSpeak(mood: line.mood, lastMood: spokenLines.mood, lastDay: spokenLines.day, today: today) else { return }
        if let last = lastAutomaticAt, now.timeIntervalSince(last) < Self.minimumGap {
            return waitForGap(since: last, now: now)
        }
        lastAutomaticAt = now
        speak(line, trigger: .automatic)
    }

    private func waitForGap(since last: Date, now: Date) {
        guard gapTimerPending == false else { return }
        gapTimerPending = true
        schedule(Self.minimumGap - now.timeIntervalSince(last)) { [weak self] in
            guard let self else { return false }
            self.gapTimerPending = false
            self.speakAutomaticallyIfDue()
            return false
        }
    }

    private func speak(_ line: PlantMonitorSpokenLine, trigger: PlantMonitorSpeechTrigger) {
        spokenLines.save(mood: line.mood, day: PlantSpokenLineStore.day(for: clock(), calendar: calendar))
        speechID += 1
        let id = speechID
        speaking = Speaking(id: id, trigger: trigger)
        voice.speak(line.text, mood: line.mood, trigger: trigger) { [weak self] in
            guard let self, self.speaking?.id == id else { return }
            self.speaking = nil
            self.speakAutomaticallyIfDue()
        }
    }

    /// Clears the state first, so the completion the voice fires for the stop is ignored.
    private func stopSpeaking() {
        guard speaking != nil else { return }
        speaking = nil
        voice.stop()
    }
}
