import Foundation
import KokoroSwift
import MLX
import os

/// Sprout's voice: Kokoro with the baked "sprout" style (af_heart × 0.45 + af_nicole × 0.55).
///
/// MLX runs only on a private serial queue, never on the main actor or the cooperative pool.
/// Closures that run on that queue are made in `nonisolated static` functions (ARCHITECTURE.md
/// section 3). Results come back through checked continuations.
@MainActor
public final class KokoroSproutGenerator {
    public enum GeneratorError: Error, Equatable {
        /// MLX needs a real Metal GPU.
        case unavailable
        /// `generate` was called while the model is neither loaded nor loading.
        case notLoaded
        case missingResources
        case failed(String)
    }

    public enum State: Equatable, Sendable {
        case notLoaded
        case loading
        case loaded
    }

    public struct LoadTimings: Equatable, Sendable {
        public let loadSeconds: Double
        public let warmUpSeconds: Double
    }

    /// Sprout talks a little faster than Kokoro's default.
    public static let baseSpeed: Float = 1.05
    nonisolated static let cacheLimit = 32 * 1_048_576
    nonisolated private static let logger = Logger(subsystem: "TalkingPlant", category: "voice")

    private let resources: URL
    private let queue = DispatchQueue(label: "PlantKokoro.generation", qos: .userInitiated)
    private var model: SproutModel?
    private var loading: Task<Void, Error>?
    private var epoch = 0
    private var utterancePeak: KokoroPeakWindow?

    public var state: State {
        if model != nil { return .loaded }
        return loading != nil ? .loading : .notLoaded
    }

    /// Of the model that is loaded now. `nil` while not loaded.
    public private(set) var timings: LoadTimings?

    /// `resources` holds `kokoro-f16.safetensors` and `sprout.safetensors`. It defaults to this package's bundle.
    public init(resources: URL? = nil) {
        self.resources = resources ?? Bundle.module.resourceURL!
    }

    /// Loads the weights and voice, generates "Hi." once (G2P + Metal kernels). Idempotent.
    public func prewarm() async throws {
        #if targetEnvironment(simulator)
        throw GeneratorError.unavailable
        #else
        if model != nil { return }
        if let loading { return try await loading.value }

        let epoch = epoch
        let resources = resources
        let queue = queue
        let task = Task { @MainActor in
            defer { self.loading = nil }
            let (loaded, timings) = try await Self.load(resources: resources, on: queue)
            // An `unload` during the load wins.
            if self.epoch == epoch {
                self.model = loaded
                self.timings = timings
            }
        }
        loading = task
        try await task.value
        #endif
    }

    /// Starts the peak-memory window of one utterance. Pair with `utteranceFinished()`.
    public func utteranceStarted() {
        utterancePeak?.stop()
        utterancePeak = KokoroPeakWindow()
    }

    /// Logs the utterance's peak and drops MLX's cached buffers, so one utterance's scratch memory
    /// is not carried into the next. Safe without a matching `utteranceStarted()`.
    public func utteranceFinished() {
        if let utterancePeak {
            Self.logger.notice("utterance peak \(KokoroMemory.megabytes(utterancePeak.peakBytes)) MB, \(KokoroMemory.current()?.megabytesDescription ?? "memory unknown")")
            utterancePeak.stop()
            self.utterancePeak = nil
        }
        Self.clearCache(on: queue)
    }

    /// Drops the model and clears MLX's cache. A pending generation finishes, then is dropped.
    public func unload() {
        epoch += 1
        utterancePeak?.stop()
        utterancePeak = nil
        model = nil
        timings = nil
        Self.clearCache(on: queue)
    }

    /// Waits for a prewarm in progress. Throws `.notLoaded` when none is running and the model
    /// isn't loaded; `.unavailable` in the Simulator. `speed` 1 is the voice's normal speed.
    public func generate(_ text: String, speed: Float) async throws -> [Float] {
        #if targetEnvironment(simulator)
        throw GeneratorError.unavailable
        #else
        if let loading { try await loading.value }
        guard let model else { throw GeneratorError.notLoaded }
        return try await Self.run(text, speed: speed * Self.baseSpeed, with: model, on: queue)
        #endif
    }

    // MARK: - Queue work

    nonisolated private static func load(resources: URL, on queue: DispatchQueue) async throws -> (SproutModel, LoadTimings) {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try SproutModel.load(resources: resources) })
            }
        }
    }

    nonisolated private static func run(
        _ text: String,
        speed: Float,
        with model: SproutModel,
        on queue: DispatchQueue
    ) async throws -> [Float] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try model.generate(text, speed: speed) })
            }
        }
    }

    nonisolated private static func clearCache(on queue: DispatchQueue) {
        queue.async { Memory.clearCache() }
    }

    /// Kokoro and the voice. Not thread-safe: used on `queue` only.
    private final class SproutModel: @unchecked Sendable {
        private let tts: KokoroTTS
        private let voice: MLXArray

        private init(tts: KokoroTTS, voice: MLXArray) {
            self.tts = tts
            self.voice = voice
        }

        static func load(resources: URL) throws -> (SproutModel, LoadTimings) {
            let weightsURL = resources.appendingPathComponent("kokoro-f16.safetensors")
            let voiceURL = resources.appendingPathComponent("sprout.safetensors")
            // `KokoroTTS` traps on an unreadable file, so check first.
            guard FileManager.default.fileExists(atPath: weightsURL.path),
                  FileManager.default.fileExists(atPath: voiceURL.path) else {
                throw GeneratorError.missingResources
            }
            let start = Date()
            // MLX keeps freed GPU buffers in a cache that otherwise grows with every request.
            Memory.cacheLimit = KokoroSproutGenerator.cacheLimit
            logger.info("MLX cache limit \(Memory.cacheLimit / 1_048_576) MB (asked for \(KokoroSproutGenerator.cacheLimit / 1_048_576) MB)")
            guard let voice = try MLX.loadArrays(url: voiceURL)["sprout"] else {
                throw GeneratorError.failed("sprout.safetensors has no \"sprout\" tensor")
            }
            let model = SproutModel(tts: KokoroTTS(modelPath: weightsURL, g2p: .misaki), voice: voice)
            let loaded = Date()
            // Warm-up: the first generation builds the G2P and the Metal kernels.
            _ = try model.generate("Hi.", speed: 1)
            let warm = Date()
            logger.info("load \(loaded.timeIntervalSince(start), format: .fixed(precision: 2)) s, warm-up \(warm.timeIntervalSince(loaded), format: .fixed(precision: 2)) s, \(Self.memoryDescription())")
            return (model, LoadTimings(
                loadSeconds: loaded.timeIntervalSince(start),
                warmUpSeconds: warm.timeIntervalSince(loaded)
            ))
        }

        func generate(_ text: String, speed: Float) throws -> [Float] {
            let start = Date()
            let samples: [Float]
            do {
                (samples, _) = try tts.generateAudio(voice: voice, language: .enUS, text: text, speed: speed)
            } catch {
                throw GeneratorError.failed(String(describing: error))
            }
            Memory.clearCache()
            logger.info("chunk \(text.count) chars in \(Date().timeIntervalSince(start), format: .fixed(precision: 2)) s, \(samples.count) samples, \(Self.memoryDescription())")
            return samples
        }

        static func memoryDescription() -> String {
            KokoroMemory.current()?.megabytesDescription ?? "memory unknown"
        }
    }
}
