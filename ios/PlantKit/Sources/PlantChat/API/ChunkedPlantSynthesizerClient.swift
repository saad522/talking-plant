import Foundation
import os

@MainActor
public final class ChunkedPlantSynthesizerClient: PlantPrimarySynthesizerClient {
    /// A chunk louder than this is treated as broken output.
    public static let maximumPeak: Float = 1.5

    /// Timings of the latest utterance, for the DEBUG voice check screen.
    public struct Metrics: Equatable, Sendable {
        public struct Chunk: Equatable, Sendable {
            public let characters: Int
            public let seconds: Double
        }

        public internal(set) var firstAudioSeconds: Double?
        public internal(set) var chunks: [Chunk] = []
        public internal(set) var watchdogFired = false
    }

    public private(set) var lastMetrics: Metrics?

    private let generator: PlantSpeechGeneratorClient
    private let player: PlantSpeechPlayerClient
    private let schedule: FallbackPlantSynthesizerClient.Schedule
    private var isActive = false
    private var task: Task<Void, Never>?
    /// Changes on every `speak` and `stop`, so late results and completions do nothing.
    private var generation = 0
    private static let logger = Logger(subsystem: "TalkingPlant", category: "voice")

    /// The first buffer must be played back within its duration plus this, or the voice has failed.
    public static let playbackGrace: TimeInterval = 1.5
    private static let sampleRate: Double = 24_000

    public init(
        generator: PlantSpeechGeneratorClient,
        player: PlantSpeechPlayerClient,
        schedule: @escaping FallbackPlantSynthesizerClient.Schedule = FallbackPlantSynthesizerClient.sleep
    ) {
        self.generator = generator
        self.player = player
        self.schedule = schedule
    }

    public func speak(_ text: String, style: PlantSpeechStyle, update: @escaping (PlantSpeechEvent) -> Void) {
        Self.logger.notice("speak: stopping previous utterance first (isActive \(self.isActive))")
        stop()
        generation += 1
        let current = generation
        let chunks = PlantSpeechChunker.chunks(text)
        Self.logger.notice("speak start: \(chunks.count) chunks, speed \(style.speed), generation \(current)")
        guard !chunks.isEmpty else {
            Self.logger.notice("speak: no chunks, finished")
            update(.finished)
            return
        }
        do {
            try player.start()
        } catch {
            Self.logger.notice("speak: player.start failed (\(String(describing: error))), .failed")
            update(.failed)
            return
        }
        isActive = true
        generator.utteranceStarted()
        lastMetrics = Metrics()
        let utterance = Utterance(chunks: chunks, speed: style.speed, begin: .now, update: update)
        requestNext(of: utterance, generation: current)
    }

    private final class Utterance {
        let chunks: [String]
        let speed: Float
        let begin: ContinuousClock.Instant
        let update: (PlantSpeechEvent) -> Void
        var nextIndex = 0
        var enqueued = 0
        var played = 0
        var isGenerating = false

        init(chunks: [String], speed: Float, begin: ContinuousClock.Instant, update: @escaping (PlantSpeechEvent) -> Void) {
            self.chunks = chunks
            self.speed = speed
            self.begin = begin
            self.update = update
        }
    }

    /// At most one generated chunk waits beyond the one playing.
    private static let maximumQueued = 2

    private func requestNext(of utterance: Utterance, generation current: Int) {
        guard !utterance.isGenerating,
              utterance.nextIndex < utterance.chunks.count,
              utterance.enqueued - utterance.played < Self.maximumQueued
        else { return }
        utterance.isGenerating = true
        generate(utterance.nextIndex, of: utterance, generation: current)
    }

    private func generate(_ index: Int, of utterance: Utterance, generation current: Int) {
        let generator = generator
        task = Task { [weak self] in
            let samples: [Float]
            let start = ContinuousClock.now
            do {
                samples = try await generator.generate(utterance.chunks[index], speed: utterance.speed)
            } catch {
                Self.logger.notice("chunk \(index) generation threw: \(String(describing: error))")
                self?.fail(utterance, generation: current)
                return
            }
            self?.generated(samples, index: index, seconds: start.duration(to: .now).seconds, of: utterance, generation: current)
        }
    }

    private func generated(_ samples: [Float], index: Int, seconds: Double, of utterance: Utterance, generation current: Int) {
        guard generation == current else {
            Self.logger.notice("chunk \(index) generated but dropped: generation \(current) is now \(self.generation)")
            return
        }
        let peak = samples.reduce(0) { max($0, abs($1)) }
        guard Self.isPlayable(samples) else {
            Self.logger.notice("chunk \(index) rejected by level check: \(samples.count) samples, peak \(peak)")
            return fail(utterance, generation: current)
        }
        lastMetrics?.chunks.append(.init(characters: utterance.chunks[index].count, seconds: seconds))
        Self.logger.notice("chunk \(index) accepted: \(samples.count) samples, peak \(peak)")
        utterance.isGenerating = false
        utterance.nextIndex = index + 1
        utterance.enqueued += 1
        Self.logger.notice("enqueue chunk \(index) (enqueued \(utterance.enqueued), played \(utterance.played), of \(utterance.chunks.count))")
        player.enqueue(samples) { [weak self] succeeded in
            self?.played(succeeded, of: utterance, generation: current)
        }
        if index == 0 {
            let firstAudio = utterance.begin.duration(to: .now).seconds
            Self.logger.info("first audio \(Int(firstAudio * 1000)) ms")
            lastMetrics?.firstAudioSeconds = firstAudio
            utterance.update(.generated)
            watchPlayback(of: utterance, samples: samples.count, generation: current)
        }
        requestNext(of: utterance, generation: current)
    }

    /// A buffer that is scheduled but never played back means the player is stuck. Treat it as a failure.
    private func watchPlayback(of utterance: Utterance, samples: Int, generation current: Int) {
        let limit = Double(samples) / Self.sampleRate + Self.playbackGrace
        schedule(limit) { [weak self] in
            guard let self, generation == current, utterance.played == 0 else { return }
            lastMetrics?.watchdogFired = true
            Self.logger.notice("playback watchdog fired: first buffer not played back after \(limit) s")
            fail(utterance, generation: current)
        }
    }

    private func played(_ succeeded: Bool, of utterance: Utterance, generation current: Int) {
        guard generation == current else {
            Self.logger.notice("player completion(\(succeeded)) dropped: generation \(current) is now \(self.generation)")
            return
        }
        Self.logger.notice("player completion(\(succeeded)), played so far \(utterance.played)")
        guard succeeded else { return fail(utterance, generation: current) }
        utterance.played += 1
        if utterance.played == 1 {
            Self.logger.notice("first buffer played back after \(Int(utterance.begin.duration(to: .now).seconds * 1000)) ms")
            utterance.update(.started)
        }
        if utterance.played == utterance.chunks.count {
            isActive = false
            generator.utteranceFinished()
            utterance.update(.finished)
        } else {
            requestNext(of: utterance, generation: current)
        }
    }

    private func fail(_ utterance: Utterance, generation current: Int) {
        guard generation == current else {
            Self.logger.notice("fail dropped: generation \(current) is now \(self.generation)")
            return
        }
        Self.logger.notice("fail: stopping player, .failed (enqueued \(utterance.enqueued), played \(utterance.played))")
        // Nothing more is sent for this utterance, not even a late played-back completion.
        generation += 1
        isActive = false
        task?.cancel()
        player.stop()
        generator.utteranceFinished()
        utterance.update(.failed)
    }

    public func stop() {
        Self.logger.notice("stop: isActive \(self.isActive), generation \(self.generation) -> \(self.generation + 1)")
        generation += 1
        task?.cancel()
        task = nil
        guard isActive else { return }
        isActive = false
        player.stop()
        generator.utteranceFinished()
    }

    private static func isPlayable(_ samples: [Float]) -> Bool {
        guard !samples.isEmpty else { return false }
        let peak = samples.reduce(0) { max($0, abs($1)) }
        return peak <= maximumPeak
    }
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
