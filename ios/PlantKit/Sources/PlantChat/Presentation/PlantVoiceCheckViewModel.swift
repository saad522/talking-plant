#if DEBUG
import Foundation
import Observation
import PlantShared

/// What the voice check screen reads from the app's voice.
public struct PlantVoiceCheckSnapshot: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case notLoaded
        case loading
        case loaded
    }

    public let voiceID: String
    public let physicalMemory: UInt64
    public let minimumPhysicalMemory: UInt64
    public let state: State
    public let loadSeconds: Double?
    public let warmUpSeconds: Double?
    public let memoryNowBytes: UInt64?
    public let memoryPeakBytes: UInt64?
    public let utterance: ChunkedPlantSynthesizerClient.Metrics?

    public init(
        voiceID: String,
        physicalMemory: UInt64,
        minimumPhysicalMemory: UInt64,
        state: State,
        loadSeconds: Double? = nil,
        warmUpSeconds: Double? = nil,
        memoryNowBytes: UInt64? = nil,
        memoryPeakBytes: UInt64? = nil,
        utterance: ChunkedPlantSynthesizerClient.Metrics? = nil
    ) {
        self.voiceID = voiceID
        self.physicalMemory = physicalMemory
        self.minimumPhysicalMemory = minimumPhysicalMemory
        self.state = state
        self.loadSeconds = loadSeconds
        self.warmUpSeconds = warmUpSeconds
        self.memoryNowBytes = memoryNowBytes
        self.memoryPeakBytes = memoryPeakBytes
        self.utterance = utterance
    }
}

@MainActor
public protocol PlantVoiceCheckClient {
    var snapshot: PlantVoiceCheckSnapshot { get }
    /// - Returns: a description of the failure, or `nil` when loaded.
    func load() async -> String?
    func unload()
    /// From now on the snapshot's peak is the peak since this call, not since launch.
    func resetPeak()
    /// `appleOnly` skips Kokoro and speaks through the fallback voice.
    func speak(_ text: String, style: PlantSpeechStyle, appleOnly: Bool, completion: @escaping () -> Void)
    func stop()
}

/// DEBUG screen data: the voice's own state and the latest utterance's timings, as text.
@MainActor
@Observable
public final class PlantVoiceCheckViewModel {
    public static let sampleSentence = "Hi, I'm Sprout. My soil is at 23 percent, and it's 21.5 degrees. I could really use a little water today."
    public static let sampleMoods: [PlantMood] = [.happy, .thirsty, .tooHot, .tooCold, .drowning]

    @ObservationIgnored private let client: PlantVoiceCheckClient
    public private(set) var snapshot: PlantVoiceCheckSnapshot
    public private(set) var loadError: String?
    public private(set) var isLoading = false
    public private(set) var speaking: String?

    public init(client: PlantVoiceCheckClient) {
        self.client = client
        snapshot = client.snapshot
    }

    public func refresh() {
        snapshot = client.snapshot
    }

    public func load() async {
        isLoading = true
        refresh()
        loadError = await client.load()
        isLoading = false
        refresh()
    }

    public func unload() {
        client.unload()
        refresh()
    }

    public func resetPeak() {
        client.resetPeak()
        refresh()
    }

    public func speakSample(mood: PlantMood) {
        speak(label: Self.label(for: mood), style: PlantPersonality.cheerful.speechStyle.adjusted(for: mood), appleOnly: false)
    }

    public func speakWithAppleVoice() {
        speak(label: "Apple", style: PlantPersonality.cheerful.speechStyle, appleOnly: true)
    }

    public func stop() {
        client.stop()
        speaking = nil
    }

    private func speak(label: String, style: PlantSpeechStyle, appleOnly: Bool) {
        speaking = label
        client.speak(Self.sampleSentence, style: style, appleOnly: appleOnly) { [weak self] in
            self?.speaking = nil
            self?.refresh()
        }
    }

    // MARK: - Text

    public static func label(for mood: PlantMood) -> String {
        String(describing: mood)
    }

    public var voiceIDText: String { snapshot.voiceID }

    public var gateText: String {
        let passes = snapshot.physicalMemory >= snapshot.minimumPhysicalMemory
        return "\(passes ? "pass" : "fail"): \(Self.gigabytes(snapshot.physicalMemory)) of \(Self.gigabytes(snapshot.minimumPhysicalMemory)) needed"
    }

    public var stateText: String {
        switch snapshot.state {
        case .notLoaded: "not loaded"
        case .loading: "loading"
        case .loaded: "loaded"
        }
    }

    public var loadText: String { Self.seconds(snapshot.loadSeconds) }
    public var warmUpText: String { Self.seconds(snapshot.warmUpSeconds) }

    public var memoryText: String {
        "\(Self.megabytes(snapshot.memoryNowBytes)) now, \(Self.megabytes(snapshot.memoryPeakBytes)) peak"
    }

    public var firstAudioText: String { Self.seconds(snapshot.utterance?.firstAudioSeconds) }

    public var chunkTexts: [String] {
        (snapshot.utterance?.chunks ?? []).enumerated().map { index, chunk in
            "\(index + 1): \(chunk.characters) chars, \(Self.seconds(chunk.seconds))"
        }
    }

    public var watchdogText: String {
        guard let utterance = snapshot.utterance else { return "-" }
        return utterance.watchdogFired ? "yes" : "no"
    }

    private static func seconds(_ value: Double?) -> String {
        value.map { String(format: "%.2f s", $0) } ?? "-"
    }

    private static func megabytes(_ bytes: UInt64?) -> String {
        bytes.map { String(format: "%.0f MB", Double($0) / 1_048_576) } ?? "-"
    }

    private static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
    }
}
#endif
