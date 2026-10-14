import Foundation

/// The voice spike screen: pick a line and a voice, tweak, Play, read the timings.
@MainActor
public final class KokoroSpikeViewModel {
    public enum Status: Equatable, Sendable {
        case idle
        case loading
        case ready
        case playing
        case unavailable(String)
    }

    public struct State: Equatable, Sendable {
        public var status: Status = .idle
        public var line: KokoroSpikeLine = .happy
        public var voice: KokoroSpikeVoice = KokoroSpikeVoice.catalog[0]
        public var blendVoice: KokoroSpikeVoice = KokoroSpikeVoice.catalog[4]
        public var blend: Float = 0
        public var pitchCents: Float = 0
        public var speed: Float = 1
        /// Load time, last run, memory. Ready to show.
        public var metrics: [String] = []
        /// The last runs, newest first.
        public var runs: [String] = []
        public var notice: String?

        public init() {}

        public var canPlay: Bool { status == .ready || status == .playing }
        public var playLabel: String { status == .playing ? "Stop" : "Play" }
        public var statusLabel: String {
            switch status {
            case .idle, .loading: "Loading model…"
            case .ready: "Ready"
            case .playing: "Playing…"
            case let .unavailable(reason): reason
            }
        }
    }

    public static let pitchRange: ClosedRange<Float> = -1200...1200
    public static let speedRange: ClosedRange<Float> = 0.5...2
    public static let maxRuns = 8

    public var onChange: ((State) -> Void)?
    public private(set) var state = State() {
        didSet { if state != oldValue { onChange?(state) } }
    }

    private let client: KokoroSpikeSynthesizerClient
    private let now: () -> TimeInterval
    private let memory: () -> KokoroSpikeMemory?
    private let log: (String) -> Void

    private var loadSeconds: Double?
    private var lastMemory: KokoroSpikeMemory?
    private var run: Run?
    private var runCount = 0

    private struct Run {
        let id: Int
        let startedAt: TimeInterval
        let summary: String
        var firstAudio: Double?
        var generation: Double?
        var audioSeconds: Double?
    }

    public init(
        client: KokoroSpikeSynthesizerClient,
        now: @escaping () -> TimeInterval,
        memory: @escaping () -> KokoroSpikeMemory?,
        log: @escaping (String) -> Void
    ) {
        self.client = client
        self.now = now
        self.memory = memory
        self.log = log
    }

    public func appear() {
        guard state.status == .idle else { return }
        state.status = .loading
        let startedAt = now()
        client.load { [weak self] result in
            self?.didLoad(result, startedAt: startedAt)
        }
    }

    public func disappear() {
        guard state.status == .playing else { return }
        client.stop()
        run = nil
        state.status = .ready
    }

    public func select(_ line: KokoroSpikeLine) { state.line = line }
    public func select(voice: KokoroSpikeVoice) { state.voice = voice }
    public func select(blendVoice: KokoroSpikeVoice) { state.blendVoice = blendVoice }
    public func setBlend(_ value: Float) { state.blend = min(max(value, 0), 1) }
    public func setPitchCents(_ value: Float) { state.pitchCents = min(max(value, Self.pitchRange.lowerBound), Self.pitchRange.upperBound) }
    public func setSpeed(_ value: Float) { state.speed = min(max(value, Self.speedRange.lowerBound), Self.speedRange.upperBound) }

    public func playTap() {
        switch state.status {
        case .playing:
            client.stop()
            run = nil
            state.status = .ready
        case .ready:
            play()
        case .idle, .loading, .unavailable:
            break
        }
    }

    private func play() {
        runCount += 1
        let id = runCount
        let request = KokoroSpikeRequest(
            chunks: KokoroSpikeSentences.chunks(state.line.text),
            voice: state.voice,
            blendVoice: state.blendVoice,
            blend: state.blend,
            pitchCents: state.pitchCents,
            speed: state.speed
        )
        run = Run(id: id, startedAt: now(), summary: summary(of: request))
        state.notice = nil
        state.status = .playing
        refreshMetrics()
        client.speak(request) { [weak self] event in
            self?.handle(event, runID: id)
        }
    }

    private func didLoad(_ result: Result<Void, KokoroSpikeLoadError>, startedAt: TimeInterval) {
        switch result {
        case .success:
            loadSeconds = now() - startedAt
            lastMemory = memory()
            state.status = .ready
            refreshMetrics()
            log("[KokoroSpike] " + state.metrics.joined(separator: " | "))
        case .failure(.missingFiles):
            state.status = .unavailable("Model files missing. Run ios/KokoroSpike/setup.sh, then clean and rebuild.")
        case let .failure(.failed(message)):
            state.status = .unavailable("Model failed to load: \(message)")
        }
    }

    private func handle(_ event: KokoroSpikeEvent, runID: Int) {
        guard var current = run, current.id == runID else { return }
        let elapsed = now() - current.startedAt
        switch event {
        case .audioStarted:
            current.firstAudio = elapsed
            run = current
        case let .generated(audioSeconds):
            current.generation = elapsed
            current.audioSeconds = audioSeconds
            run = current
        case .finished:
            lastMemory = memory()
            record(current)
            state.status = .ready
        case let .failed(message):
            lastMemory = memory()
            run = nil
            state.notice = "Failed: \(message)"
            state.status = .ready
        }
        refreshMetrics()
    }

    private func record(_ finished: Run) {
        run = finished
        let line = "#\(finished.id) \(finished.summary): " + Self.timings(of: finished).joined(separator: " · ")
        state.runs = Array(([line] + state.runs).prefix(Self.maxRuns))
        log("[KokoroSpike] " + line)
    }

    private func summary(of request: KokoroSpikeRequest) -> String {
        var voices = request.voice.id
        if request.blend > 0 {
            voices += String(format: " + %.0f%% %@", request.blend * 100, request.blendVoice.id)
        }
        return String(format: "%@ · %@ · %+.0f ct · ×%.2f", state.line.label, voices, request.pitchCents, request.speed)
    }

    private func refreshMetrics() {
        var lines: [String] = []
        if let loadSeconds {
            lines.append(String(format: "Model load + warm-up: %.2f s", loadSeconds))
        }
        if let run {
            lines.append(contentsOf: Self.timings(of: run))
        }
        if let lastMemory {
            lines.append(String(format: "Memory: %.0f MB now · %.0f MB peak", Self.megabytes(lastMemory.currentBytes), Self.megabytes(lastMemory.peakBytes)))
        }
        state.metrics = lines
    }

    private static func timings(of run: Run) -> [String] {
        var lines: [String] = []
        if let firstAudio = run.firstAudio {
            lines.append(String(format: "First audio: %.2f s", firstAudio))
        }
        if let generation = run.generation, let audioSeconds = run.audioSeconds {
            let realTime = generation > 0 ? audioSeconds / generation : 0
            lines.append(String(format: "Generation: %.2f s for %.2f s of audio (%.1f× real time)", generation, audioSeconds, realTime))
        }
        return lines
    }

    private static func megabytes(_ bytes: UInt64) -> Double {
        Double(bytes) / 1_048_576
    }
}
