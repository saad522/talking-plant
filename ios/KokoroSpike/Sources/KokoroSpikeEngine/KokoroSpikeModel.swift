import Foundation
import KokoroSpike
import KokoroSwift
import MLX
import MLXUtilsLibrary

/// Kokoro's weights and voice packs. Not thread-safe: the client uses it on one serial queue only.
final class KokoroSpikeModel: @unchecked Sendable {
    enum ModelError: Error, CustomStringConvertible {
        case noVoices
        case unknownVoice(String)

        var description: String {
            switch self {
            case .noVoices: "voices.npz has no voices"
            case let .unknownVoice(id): "no voice named \(id)"
            }
        }
    }

    private let tts: KokoroTTS
    private let voices: [String: MLXArray]

    /// Loads the weights (`KokoroTTS` traps on an unreadable file, so check it exists first).
    init(modelURL: URL, voicesURL: URL) throws {
        // MLX keeps freed GPU buffers in a cache that otherwise grows with every request.
        Memory.cacheLimit = Self.cacheLimit
        tts = KokoroTTS(modelPath: modelURL, g2p: .misaki)
        voices = NpyzReader.read(fileFromPath: voicesURL) ?? [:]
        guard !voices.isEmpty else { throw ModelError.noVoices }
    }

    /// 24 kHz mono samples for one chunk.
    func generate(_ text: String, request: KokoroSpikeRequest) throws -> [Float] {
        let style = try style(for: request)
        let language: Language = request.voice.isBritish ? .enGB : .enUS
        let (samples, _) = try tts.generateAudio(voice: style, language: language, text: text, speed: request.speed)
        Memory.clearCache()
        return samples
    }

    static let cacheLimit = 32 * 1_048_576

    /// A blend is a straight mix of the two style tables (510 × 1 × 256 each).
    private func style(for request: KokoroSpikeRequest) throws -> MLXArray {
        let first = try voice(request.voice.id)
        guard request.blend > 0 else { return first }
        let second = try voice(request.blendVoice.id)
        guard request.blend < 1 else { return second }
        return first * (1 - request.blend) + second * request.blend
    }

    private func voice(_ id: String) throws -> MLXArray {
        guard let voice = voices[id + ".npy"] ?? voices[id] else { throw ModelError.unknownVoice(id) }
        return voice
    }
}
