import Foundation

public enum KokoroSpikeEvent: Equatable, Sendable {
    /// The first chunk is playing.
    case audioStarted
    /// Every chunk is generated; `audioSeconds` is the length of all of them.
    case generated(audioSeconds: Double)
    /// Everything was played back.
    case finished
    case failed(String)
}

/// Process memory, read after load and after each Play.
public struct KokoroSpikeMemory: Equatable, Sendable {
    public let currentBytes: UInt64
    public let peakBytes: UInt64

    public init(currentBytes: UInt64, peakBytes: UInt64) {
        self.currentBytes = currentBytes
        self.peakBytes = peakBytes
    }
}

@MainActor
public protocol KokoroSpikeSynthesizerClient: AnyObject {
    /// Loads the weights and voices and runs one warm-up generation. Completes exactly once.
    func load(completion: @escaping (Result<Void, KokoroSpikeLoadError>) -> Void)
    /// Sends `.audioStarted` once, `.generated` once, then `.finished`; or `.failed` at any point,
    /// after which nothing more is sent. Nothing is sent after `stop()`.
    func speak(_ request: KokoroSpikeRequest, update: @escaping (KokoroSpikeEvent) -> Void)
    /// Stops at once, synchronously.
    func stop()
}

public enum KokoroSpikeLoadError: Error, Equatable, Sendable {
    /// `setup.sh` wasn't run, or the build didn't copy the files.
    case missingFiles
    case failed(String)
}
