import Foundation
import os

@MainActor
public final class FallbackPlantSynthesizerClient: PlantSynthesizerClient {
    public typealias Schedule = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Void

    public static let startTimeout: TimeInterval = 3
    /// Used instead when the primary model is still loading at `speak`.
    public static let loadingStartTimeout: TimeInterval = 8

    private enum Phase {
        case idle
        case primary(started: Bool)
        case fallback
    }

    private let primary: PlantPrimarySynthesizerClient
    private let fallback: PlantSynthesizerClient
    private let isPrimaryLoading: () -> Bool
    private let schedule: Schedule
    private var phase = Phase.idle
    private var completion: (() -> Void)?
    /// The primary voice has its first audio. Its own watchdog decides whether playback works.
    private var primaryGenerated = false
    /// Changes on every `speak` and `stop`, so older events, timers and completions do nothing.
    private var generation = 0
    private static let logger = Logger(subsystem: "TalkingPlant", category: "voice")

    public init(
        primary: PlantPrimarySynthesizerClient,
        fallback: PlantSynthesizerClient,
        isPrimaryLoading: @escaping () -> Bool = { false },
        schedule: @escaping Schedule = FallbackPlantSynthesizerClient.sleep
    ) {
        self.primary = primary
        self.fallback = fallback
        self.isPrimaryLoading = isPrimaryLoading
        self.schedule = schedule
    }

    public static func sleep(_ interval: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(interval))
            action()
        }
    }

    public func speak(_ text: String, style: PlantSpeechStyle, completion: @escaping () -> Void) {
        stop(from: "speak (previous utterance)")
        generation += 1
        let current = generation
        Self.logger.debug("speak start: generation \(current), primary first")
        self.completion = completion
        phase = .primary(started: false)
        primaryGenerated = false
        primary.speak(text, style: style) { [weak self] event in
            self?.handle(event, text: text, style: style, generation: current)
        }
        schedule(isPrimaryLoading() ? Self.loadingStartTimeout : Self.startTimeout) { [weak self] in
            guard let self, generation == current, case .primary(started: false) = phase, !primaryGenerated else {
                Self.logger.debug("start timeout ignored (generation \(current), phase \(String(describing: self?.phase)))")
                return
            }
            Self.logger.notice("Primary voice did not start in time, using the fallback voice")
            primary.stop()
            speakWithFallback(text, style: style, generation: current)
        }
    }

    public func stop() {
        stop(from: "caller")
    }

    private func stop(from source: String) {
        generation += 1
        let previous = phase
        Self.logger.debug("stop from: \(source), phase \(String(describing: previous)), completion pending \(self.completion != nil)")
        phase = .idle
        switch previous {
        case .idle: break
        case .primary: primary.stop()
        case .fallback: fallback.stop()
        }
        complete()
    }

    private func handle(_ event: PlantSpeechEvent, text: String, style: PlantSpeechStyle, generation current: Int) {
        guard generation == current, case .primary(let started) = phase else {
            Self.logger.debug("primary event \(String(describing: event)) dropped: generation \(current) is now \(self.generation), phase \(String(describing: self.phase))")
            return
        }
        Self.logger.debug("primary event \(String(describing: event)), started \(started)")
        switch event {
        case .generated:
            primaryGenerated = true
        case .started:
            phase = .primary(started: true)
        case .finished:
            finish()
        case .failed where started:
            Self.logger.notice("Primary voice failed mid-reply, ending the turn")
            finish()
        case .failed:
            Self.logger.notice("Primary voice failed before starting, using the fallback voice")
            speakWithFallback(text, style: style, generation: current)
        }
    }

    private func speakWithFallback(_ text: String, style: PlantSpeechStyle, generation current: Int) {
        phase = .fallback
        Self.logger.notice("fallback voice speaking (generation \(current))")
        fallback.speak(text, style: style) { [weak self] in
            guard let self, generation == current else {
                Self.logger.debug("fallback completion dropped: generation \(current) is now \(self?.generation ?? -1)")
                return
            }
            Self.logger.debug("fallback voice finished")
            finish()
        }
    }

    private func finish() {
        Self.logger.debug("finish: turn ends")
        phase = .idle
        complete()
    }

    private func complete() {
        guard let pending = completion else { return }
        completion = nil
        pending()
    }
}
