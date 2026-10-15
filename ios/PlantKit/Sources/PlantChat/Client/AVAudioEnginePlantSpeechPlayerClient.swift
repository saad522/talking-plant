import AVFoundation
import os

@MainActor
public final class AVAudioEnginePlantSpeechPlayerClient: PlantSpeechPlayerClient {
    private static let sampleRate: Double = 24_000

    private var graph: (engine: AVAudioEngine, player: AVAudioPlayerNode, format: AVAudioFormat)?
    private var pending: [Int: (Bool) -> Void] = [:]
    private var generation = 0
    private var nextIndex = 0
    private var observers: [NSObjectProtocol] = []
    private static let logger = Logger(subsystem: "TalkingPlant", category: "voice")

    public init() {}

    isolated deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    public func start() throws {
        let graph = try makeGraphIfNeeded()
        guard !graph.engine.isRunning else {
            // A running engine can still have a stopped node, which accepts buffers and never plays them.
            if !graph.player.isPlaying { graph.player.play() }
            Self.logger.debug("player.start: engine already running, \(Self.state(of: graph))")
            return
        }
        do {
            try graph.engine.start()
        } catch {
            Self.logger.debug("player.start: engine.start failed: \(String(describing: error)), \(Self.state(of: graph))")
            throw error
        }
        graph.player.play()
        Self.logger.debug("player.start: engine started, \(Self.state(of: graph))")
    }

    public func enqueue(_ samples: [Float], completion: @escaping (Bool) -> Void) {
        Self.logger.debug("player.enqueue: \(samples.count) samples, before: \(self.graph.map { Self.state(of: $0) } ?? "no graph")")
        guard let graph = try? makeGraphIfNeeded(),
              let buffer = Self.makeBuffer(samples, format: graph.format),
              (graph.engine.isRunning || (try? start()) != nil) else {
            let expected = generation
            Self.logger.debug("player.enqueue failed (graph \(self.graph != nil), engine running \(self.graph?.engine.isRunning ?? false), \(samples.count) samples): completion(false) next turn of the run loop")
            DispatchQueue.main.async { MainActor.assumeIsolated { [weak self] in
                guard let self, self.generation == expected else {
                    Self.logger.debug("player.enqueue failure completion dropped: generation \(expected) is now \(self?.generation ?? -1)")
                    return
                }
                completion(false)
            } }
            return
        }
        let index = nextIndex
        nextIndex += 1
        pending[index] = completion
        Self.logger.debug("player.enqueue: buffer \(index), \(samples.count) samples, generation \(self.generation), scheduled: \(Self.state(of: graph))")
        graph.player.scheduleBuffer(
            buffer,
            completionCallbackType: .dataPlayedBack,
            completionHandler: Self.playbackHandler(self, generation: generation, index: index)
        )
    }

    public func stop() {
        Self.logger.debug("player.stop: \(self.pending.count) pending dropped, generation \(self.generation) -> \(self.generation + 1)")
        generation += 1
        pending.removeAll()
        resetGraph()
    }

    /// The one way playback ends, for `stop()` and for the natural end: node first, then engine.
    /// An engine stopped alone leaves the node in a state where the next buffers never play back.
    private func resetGraph() {
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
                Self.logger.debug("AVAudioEngineConfigurationChange, \(engine.isRunning ? "engine running" : "engine not running")")
                MainActor.assumeIsolated { self?.playbackBroke(rebuild: false) }
            }
        ]
        #if os(iOS)
        observers += [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
                let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                Self.logger.debug("AVAudioSession interruption, type \(rawType.map(String.init) ?? "nil") (1 began, 0 ended)")
                MainActor.assumeIsolated {
                    if rawType.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began {
                        self?.playbackBroke(rebuild: false)
                    }
                }
            },
            center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
                Self.logger.debug("AVAudioSession media services were reset")
                MainActor.assumeIsolated { self?.playbackBroke(rebuild: true) }
            }
        ]
        #endif
    }

    /// Fails every pending buffer. The graph is rebuilt on the next `start()` after a media reset.
    private func playbackBroke(rebuild: Bool) {
        let failed = pending.values
        Self.logger.debug("playbackBroke(rebuild: \(rebuild)): failing \(failed.count) pending, engine running \(self.graph?.engine.isRunning ?? false)")
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
        guard generation == self.generation, let completion = pending.removeValue(forKey: index) else {
            Self.logger.debug("player buffer \(index) played-back callback dropped: generation \(generation) is now \(self.generation)")
            return
        }
        Self.logger.debug("player buffer \(index) played back, \(self.pending.count) still pending: completion(true)")
        if pending.isEmpty, let graph {
            Self.logger.debug("player: last buffer played, resetting node and engine, before: \(Self.state(of: graph))")
            resetGraph()
        }
        completion(true)
    }

    /// Engine, player node, audio session and route, for the voice logs.
    private static func state(of graph: (engine: AVAudioEngine, player: AVAudioPlayerNode, format: AVAudioFormat)) -> String {
        let engine = "engine.isRunning \(graph.engine.isRunning), player.isPlaying \(graph.player.isPlaying)"
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs.map { "\($0.portType.rawValue) \($0.portName)" }.joined(separator: ", ")
        return "\(engine), session \(session.category.rawValue)/\(session.mode.rawValue), route [\(outputs)]"
        #else
        return engine
        #endif
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
