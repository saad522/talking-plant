import Foundation
import os

@MainActor
public final class ChunkedPlantSynthesizerClient: PlantPrimarySynthesizerClient {
    /// A chunk louder than this is treated as broken output.
    public static let maximumPeak: Float = 1.5

    private let generator: PlantSpeechGeneratorClient
    private let player: PlantSpeechPlayerClient
    private var isActive = false
    private var task: Task<Void, Never>?
    /// Changes on every `speak` and `stop`, so late results and completions do nothing.
    private var generation = 0
    private static let logger = Logger(subsystem: "TalkingPlant", category: "voice")

    public init(generator: PlantSpeechGeneratorClient, player: PlantSpeechPlayerClient) {
        self.generator = generator
        self.player = player
    }

    public func speak(_ text: String, style: PlantSpeechStyle, update: @escaping (PlantSpeechEvent) -> Void) {
        stop()
        generation += 1
        let current = generation
        let chunks = PlantSpeechChunker.chunks(text)
        guard !chunks.isEmpty else {
            update(.finished)
            return
        }
        do {
            try player.start()
        } catch {
            update(.failed)
            return
        }
        isActive = true
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
            do {
                samples = try await generator.generate(utterance.chunks[index], speed: utterance.speed)
            } catch {
                self?.fail(utterance, generation: current)
                return
            }
            self?.generated(samples, index: index, of: utterance, generation: current)
        }
    }

    private func generated(_ samples: [Float], index: Int, of utterance: Utterance, generation current: Int) {
        guard generation == current else { return }
        guard Self.isPlayable(samples) else { return fail(utterance, generation: current) }
        utterance.isGenerating = false
        utterance.nextIndex = index + 1
        utterance.enqueued += 1
        player.enqueue(samples) { [weak self] succeeded in
            self?.played(succeeded, of: utterance, generation: current)
        }
        if index == 0 {
            Self.logger.info("first audio \(utterance.begin.duration(to: .now).formatted())")
            utterance.update(.started)
        }
        requestNext(of: utterance, generation: current)
    }

    private func played(_ succeeded: Bool, of utterance: Utterance, generation current: Int) {
        guard generation == current else { return }
        guard succeeded else { return fail(utterance, generation: current) }
        utterance.played += 1
        if utterance.played == utterance.chunks.count {
            isActive = false
            utterance.update(.finished)
        } else {
            requestNext(of: utterance, generation: current)
        }
    }

    private func fail(_ utterance: Utterance, generation current: Int) {
        guard generation == current else { return }
        isActive = false
        task?.cancel()
        player.stop()
        utterance.update(.failed)
    }

    public func stop() {
        generation += 1
        task?.cancel()
        task = nil
        guard isActive else { return }
        isActive = false
        player.stop()
    }

    private static func isPlayable(_ samples: [Float]) -> Bool {
        guard !samples.isEmpty else { return false }
        let peak = samples.reduce(0) { max($0, abs($1)) }
        return peak <= maximumPeak
    }
}
