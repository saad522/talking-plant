import Foundation

/// One Play: what to say and how.
public struct KokoroSpikeRequest: Equatable, Sendable {
    /// Sentence chunks, generated and played one after the other.
    public let chunks: [String]
    public let voice: KokoroSpikeVoice
    public let blendVoice: KokoroSpikeVoice
    /// 0 is only `voice`, 1 is only `blendVoice`. The style vectors are mixed linearly.
    public let blend: Float
    /// Pitch shift through AVAudioUnitTimePitch, in cents (100 = one semitone).
    public let pitchCents: Float
    /// Kokoro's own speed (durations), 1 is normal.
    public let speed: Float

    public init(chunks: [String], voice: KokoroSpikeVoice, blendVoice: KokoroSpikeVoice, blend: Float, pitchCents: Float, speed: Float) {
        self.chunks = chunks
        self.voice = voice
        self.blendVoice = blendVoice
        self.blend = blend
        self.pitchCents = pitchCents
        self.speed = speed
    }
}
