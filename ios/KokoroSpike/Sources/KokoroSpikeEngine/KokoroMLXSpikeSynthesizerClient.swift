import AVFoundation
import Foundation
import KokoroSpike
import KokoroSwift
import MLX
import Synchronization

/// Generates each chunk with Kokoro on a background queue and plays it through
/// `AVAudioPlayerNode → AVAudioUnitTimePitch → mainMixerNode`, the graph M5c planned.
///
/// Threading (ARCHITECTURE.md section 3): Kokoro runs only on `queue`. Results come back with
/// `DispatchQueue.main.async` + `MainActor.assumeIsolated`, which keeps their order. Closures
/// that run off the main thread are made in `nonisolated static` functions.
@MainActor
public final class KokoroMLXSpikeSynthesizerClient: KokoroSpikeSynthesizerClient {
    private let modelURL: URL?
    private let voicesURL: URL?
    private let queue = DispatchQueue(label: "KokoroSpike.generation", qos: .userInitiated)
    private let current = CurrentRun()

    private var model: KokoroSpikeModel?
    private var update: ((KokoroSpikeEvent) -> Void)?
    private var runID = 0
    private var scheduled = 0
    private var played = 0
    private var isGenerated = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Double(KokoroTTS.Constants.samplingRate), channels: 1)!
    private var isGraphBuilt = false

    public init(modelURL: URL?, voicesURL: URL?) {
        self.modelURL = modelURL
        self.voicesURL = voicesURL
    }

    /// The files `setup.sh` puts in this package's resources.
    public static func bundled() -> KokoroMLXSpikeSynthesizerClient {
        KokoroMLXSpikeSynthesizerClient(
            modelURL: Bundle.module.url(forResource: "kokoro-v1_0", withExtension: "safetensors", subdirectory: "Models"),
            voicesURL: Bundle.module.url(forResource: "voices", withExtension: "npz", subdirectory: "Models")
        )
    }

    // MARK: - Load

    public func load(completion: @escaping (Result<Void, KokoroSpikeLoadError>) -> Void) {
        #if targetEnvironment(simulator)
        // MLX needs a real Metal GPU.
        completion(.failure(.failed("MLX doesn't run in the iOS Simulator, use an iPhone")))
        return
        #else
        guard let modelURL, let voicesURL,
              FileManager.default.fileExists(atPath: modelURL.path),
              FileManager.default.fileExists(atPath: voicesURL.path) else {
            completion(.failure(.missingFiles))
            return
        }
        loadCompletion = completion
        Self.loadModel(modelURL: modelURL, voicesURL: voicesURL, on: queue, deliver: Self.loadHop(to: self))
        #endif
    }

    private var loadCompletion: ((Result<Void, KokoroSpikeLoadError>) -> Void)?

    private func didLoad(_ result: Result<KokoroSpikeModel, KokoroSpikeLoadError>) {
        model = try? result.get()
        let completion = loadCompletion
        loadCompletion = nil
        completion?(result.map { _ in })
    }

    nonisolated private static func loadModel(
        modelURL: URL,
        voicesURL: URL,
        on queue: DispatchQueue,
        deliver: @escaping @Sendable (Result<KokoroSpikeModel, KokoroSpikeLoadError>) -> Void
    ) {
        queue.async {
            do {
                let model = try KokoroSpikeModel(modelURL: modelURL, voicesURL: voicesURL)
                // Warm-up: the first generation builds the G2P and the Metal kernels.
                let warmUp = KokoroSpikeRequest(
                    chunks: ["Hi."],
                    voice: KokoroSpikeVoice.catalog[0],
                    blendVoice: KokoroSpikeVoice.catalog[0],
                    blend: 0,
                    pitchCents: 0,
                    speed: 1
                )
                _ = try model.generate("Hi.", request: warmUp)
                deliver(.success(model))
            } catch {
                deliver(.failure(.failed(String(describing: error))))
            }
        }
    }

    nonisolated private static func loadHop(
        to client: KokoroMLXSpikeSynthesizerClient
    ) -> @Sendable (Result<KokoroSpikeModel, KokoroSpikeLoadError>) -> Void {
        { [weak client] result in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { client?.didLoad(result) }
            }
        }
    }

    // MARK: - Speak

    public func speak(_ request: KokoroSpikeRequest, update: @escaping (KokoroSpikeEvent) -> Void) {
        stop()
        guard let model else {
            update(.failed("model not loaded"))
            return
        }
        runID += 1
        current.set(runID)
        self.update = update
        scheduled = 0
        played = 0
        isGenerated = false

        do {
            try activateSession()
            buildGraphIfNeeded()
            timePitch.pitch = request.pitchCents
            try engine.start()
        } catch {
            fail("audio engine: \(error.localizedDescription)")
            return
        }
        Self.generate(request, with: model, runID: runID, current: current, on: queue, deliver: Self.generationHop(to: self, runID: runID))
    }

    public func stop() {
        runID += 1
        current.set(runID)
        update = nil
        guard isGraphBuilt else { return }
        player.stop()
        engine.stop()
        deactivateSession()
    }

    private enum GenerationEvent: Sendable {
        case chunk([Float])
        case done(totalSamples: Int)
        case failed(String)
    }

    private func handle(_ event: GenerationEvent, runID: Int) {
        guard runID == self.runID else { return }
        switch event {
        case let .chunk(samples):
            schedule(samples, runID: runID)
        case let .done(totalSamples):
            isGenerated = true
            update?(.generated(audioSeconds: Double(totalSamples) / format.sampleRate))
            finishIfPlayedBack()
        case let .failed(message):
            fail(message)
        }
    }

    private func schedule(_ samples: [Float], runID: Int) {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { source in
            channel.update(from: source.baseAddress!, count: samples.count)
        }
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack, completionHandler: Self.playedBackHop(to: self, runID: runID))
        scheduled += 1
        if scheduled == 1 {
            player.play()
            update?(.audioStarted)
        }
    }

    private func didPlayBack(runID: Int) {
        guard runID == self.runID else { return }
        played += 1
        finishIfPlayedBack()
    }

    private func finishIfPlayedBack() {
        guard isGenerated, played == scheduled else { return }
        let update = self.update
        stop()
        update?(scheduled == 0 ? .failed("no audio") : .finished)
    }

    private func fail(_ message: String) {
        let update = self.update
        stop()
        update?(.failed(message))
    }

    nonisolated private static func generate(
        _ request: KokoroSpikeRequest,
        with model: KokoroSpikeModel,
        runID: Int,
        current: CurrentRun,
        on queue: DispatchQueue,
        deliver: @escaping @Sendable (GenerationEvent) -> Void
    ) {
        queue.async {
            var totalSamples = 0
            for chunk in request.chunks {
                guard current.is(runID) else { return }
                do {
                    let samples = try model.generate(chunk, request: request)
                    totalSamples += samples.count
                    deliver(.chunk(samples))
                } catch {
                    deliver(.failed(String(describing: error)))
                    return
                }
            }
            deliver(.done(totalSamples: totalSamples))
        }
    }

    nonisolated private static func generationHop(
        to client: KokoroMLXSpikeSynthesizerClient,
        runID: Int
    ) -> @Sendable (GenerationEvent) -> Void {
        { [weak client] event in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { client?.handle(event, runID: runID) }
            }
        }
    }

    nonisolated private static func playedBackHop(
        to client: KokoroMLXSpikeSynthesizerClient,
        runID: Int
    ) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        { [weak client] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { client?.didPlayBack(runID: runID) }
            }
        }
    }

    // MARK: - Audio

    private func buildGraphIfNeeded() {
        guard !isGraphBuilt else { return }
        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        engine.prepare()
        isGraphBuilt = true
    }

    private func activateSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)
        #endif
    }

    private func deactivateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}

/// The run the background queue should still be generating for. Bumped by `speak` and `stop`.
final class CurrentRun: Sendable {
    private let id = Mutex(0)

    func set(_ value: Int) { id.withLock { $0 = value } }
    func `is`(_ value: Int) -> Bool { id.withLock { $0 == value } }
}
