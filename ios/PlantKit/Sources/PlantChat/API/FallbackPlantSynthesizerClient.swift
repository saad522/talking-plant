import Foundation
import os

@MainActor
public final class FallbackPlantSynthesizerClient: PlantSynthesizerClient {
    public typealias Schedule = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Void

    public static let startTimeout: TimeInterval = 3

    private enum Phase {
        case idle
        case primary(started: Bool)
        case fallback
    }

    private let primary: PlantPrimarySynthesizerClient
    private let fallback: PlantSynthesizerClient
    private let schedule: Schedule
    private var phase = Phase.idle
    private var completion: (() -> Void)?
    /// Changes on every `speak` and `stop`, so older events, timers and completions do nothing.
    private var generation = 0
    private static let logger = Logger(subsystem: "TalkingPlant", category: "voice")

    public init(
        primary: PlantPrimarySynthesizerClient,
        fallback: PlantSynthesizerClient,
        schedule: @escaping Schedule = FallbackPlantSynthesizerClient.sleep
    ) {
        self.primary = primary
        self.fallback = fallback
        self.schedule = schedule
    }

    public static func sleep(_ interval: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(interval))
            action()
        }
    }

    public func speak(_ text: String, style: PlantSpeechStyle, completion: @escaping () -> Void) {
        stop()
        generation += 1
        let current = generation
        self.completion = completion
        phase = .primary(started: false)
        primary.speak(text, style: style) { [weak self] event in
            self?.handle(event, text: text, style: style, generation: current)
        }
        schedule(Self.startTimeout) { [weak self] in
            guard let self, generation == current, case .primary(started: false) = phase else { return }
            Self.logger.info("Primary voice did not start in time, using the fallback voice")
            primary.stop()
            speakWithFallback(text, style: style, generation: current)
        }
    }

    public func stop() {
        generation += 1
        let previous = phase
        phase = .idle
        switch previous {
        case .idle: break
        case .primary: primary.stop()
        case .fallback: fallback.stop()
        }
        complete()
    }

    private func handle(_ event: PlantSpeechEvent, text: String, style: PlantSpeechStyle, generation current: Int) {
        guard generation == current, case .primary(let started) = phase else { return }
        switch event {
        case .started:
            phase = .primary(started: true)
        case .finished:
            finish()
        case .failed where started:
            Self.logger.info("Primary voice failed mid-reply, ending the turn")
            finish()
        case .failed:
            Self.logger.info("Primary voice failed before starting, using the fallback voice")
            speakWithFallback(text, style: style, generation: current)
        }
    }

    private func speakWithFallback(_ text: String, style: PlantSpeechStyle, generation current: Int) {
        phase = .fallback
        fallback.speak(text, style: style) { [weak self] in
            guard let self, generation == current else { return }
            finish()
        }
    }

    private func finish() {
        phase = .idle
        complete()
    }

    private func complete() {
        guard let pending = completion else { return }
        completion = nil
        pending()
    }
}
