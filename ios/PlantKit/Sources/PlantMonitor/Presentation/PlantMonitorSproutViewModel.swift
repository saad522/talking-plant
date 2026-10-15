import Foundation
import PlantShared

/// Sprout speaking on home: when it talks on its own, and what a tap does (docs/plans/P1-alive.md D7).
@MainActor
public final class PlantMonitorSproutViewModel {
    public static let settleDelay: TimeInterval = 2.5
    public static let minimumGap: TimeInterval = 60
    public static let shakeCooldown: TimeInterval = 10
    public static let shakeLineDelay: TimeInterval = 0.4
    public static let surpriseDuration: TimeInterval = 1.0

    private let voice: PlantMonitorVoice
    private let spokenLines: PlantSpokenLineStore
    private let isEnabled: () -> Bool
    private let clock: () -> Date
    private let calendar: Calendar
    private let schedule: SimulatedPeripheralClient.Schedule
    private let shakeLoader: PlantShakeLoader
    private var shakeLines: PlantMonitorShakeLines

    /// True while the face should look surprised. Set by a shake, cleared 1 s later.
    public var loadedSurprised: ((Bool) -> Void)?

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
    private var isSubscribedToShakes = false
    private var lastShakeAt: Date?

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
        schedule: @escaping SimulatedPeripheralClient.Schedule,
        shakeLoader: PlantShakeLoader,
        randomIndex: @escaping (Int) -> Int
    ) {
        self.voice = voice
        self.spokenLines = spokenLines
        self.isEnabled = isEnabled
        self.clock = clock
        self.calendar = calendar
        self.schedule = schedule
        self.shakeLoader = shakeLoader
        shakeLines = PlantMonitorShakeLines(randomIndex: randomIndex)
    }

    public func appear() {
        isVisible = true
        subscribeToShakes()
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

    private func subscribeToShakes() {
        guard isSubscribedToShakes == false else { return }
        isSubscribedToShakes = true
        shakeLoader.subscribe { [weak self] in self?.shake() }
    }

    /// Home only, with a mood known, and not more than once every `shakeCooldown`.
    /// The face turns surprised, the line follows a moment later, and the face calms down after a second.
    private func shake() {
        guard isOpen, let line = latestLine else { return }
        let now = clock()
        if let last = lastShakeAt, now.timeIntervalSince(last) < Self.shakeCooldown { return }
        lastShakeAt = now
        stopSpeaking()
        loadedSurprised?(true)
        schedule(Self.shakeLineDelay) { [weak self] in
            self?.speakShakeLine(mood: line.mood, isSleeping: line.isSleeping)
            return false
        }
        schedule(Self.surpriseDuration) { [weak self] in
            self?.loadedSurprised?(false)
            return false
        }
    }

    private func speakShakeLine(mood: PlantMood, isSleeping: Bool) {
        guard isOpen, speaking == nil, isEnabled() else { return }
        speak(shakeLines.next(for: mood, isSleeping: isSleeping), mood: mood, trigger: .automatic, remembers: false)
    }

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
        speak(line.text, mood: line.mood, trigger: trigger, remembers: true)
    }

    /// Shake lines don't count as the day's line, so they leave the spoken-line memory alone.
    private func speak(_ text: String, mood: PlantMood, trigger: PlantMonitorSpeechTrigger, remembers: Bool) {
        if remembers {
            spokenLines.save(mood: mood, day: PlantSpokenLineStore.day(for: clock(), calendar: calendar))
        }
        speechID += 1
        let id = speechID
        speaking = Speaking(id: id, trigger: trigger)
        voice.speak(text, mood: mood, trigger: trigger) { [weak self] in
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
