import AVFoundation

@MainActor
public final class AVAudioEnginePlantSpeechPlayerClient: PlantSpeechPlayerClient {
    private static let sampleRate: Double = 24_000

    private var graph: (engine: AVAudioEngine, player: AVAudioPlayerNode, format: AVAudioFormat)?
    private var pending: [Int: (Bool) -> Void] = [:]
    private var generation = 0
    private var nextIndex = 0
    private var observers: [NSObjectProtocol] = []

    public init() {}

    isolated deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    public func start() throws {
        let graph = try makeGraphIfNeeded()
        guard !graph.engine.isRunning else { return }
        try graph.engine.start()
        graph.player.play()
    }

    public func enqueue(_ samples: [Float], completion: @escaping (Bool) -> Void) {
        guard let graph = try? makeGraphIfNeeded(),
              let buffer = Self.makeBuffer(samples, format: graph.format),
              (graph.engine.isRunning || (try? start()) != nil) else {
            let expected = generation
            DispatchQueue.main.async { MainActor.assumeIsolated { [weak self] in
                guard let self, self.generation == expected else { return }
                completion(false)
            } }
            return
        }
        let index = nextIndex
        nextIndex += 1
        pending[index] = completion
        graph.player.scheduleBuffer(
            buffer,
            completionCallbackType: .dataPlayedBack,
            completionHandler: Self.playbackHandler(self, generation: generation, index: index)
        )
    }

    public func stop() {
        generation += 1
        pending.removeAll()
        guard let graph else { return }
        graph.player.stop()
        graph.engine.stop()
    }

    private func makeGraphIfNeeded() throws -> (engine: AVAudioEngine, player: AVAudioPlayerNode, format: AVAudioFormat) {
        if let graph { return graph }
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: 1, interleaved: false) else {
            throw PlantSpeechPlayerError.unsupportedFormat
        }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        let graph = (engine: engine, player: player, format: format)
        self.graph = graph
        observe(engine)
        return graph
    }

    private func observe(_ engine: AVAudioEngine) {
        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
        observers = [
            center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.playbackBroke(rebuild: false) }
            }
        ]
        #if os(iOS)
        observers += [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
                let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                MainActor.assumeIsolated {
                    if rawType.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began {
                        self?.playbackBroke(rebuild: false)
                    }
                }
            },
            center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.playbackBroke(rebuild: true) }
            }
        ]
        #endif
    }

    /// Fails every pending buffer. The graph is rebuilt on the next `start()` after a media reset.
    private func playbackBroke(rebuild: Bool) {
        let failed = pending.values
        generation += 1
        pending.removeAll()
        if let graph {
            graph.player.stop()
            graph.engine.stop()
        }
        if rebuild {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            graph = nil
        }
        failed.forEach { $0(false) }
    }

    private func played(generation: Int, index: Int) {
        guard generation == self.generation, let completion = pending.removeValue(forKey: index) else { return }
        if pending.isEmpty { graph?.engine.stop() }
        completion(true)
    }

    private nonisolated static func makeBuffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        return buffer
    }

    /// Runs on an audio thread, so it is made here and not inferred `@MainActor`.
    private nonisolated static func playbackHandler(
        _ client: AVAudioEnginePlantSpeechPlayerClient,
        generation: Int,
        index: Int
    ) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        { [weak client] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { client?.played(generation: generation, index: index) }
            }
        }
    }
}

private enum PlantSpeechPlayerError: Error {
    case unsupportedFormat
}
