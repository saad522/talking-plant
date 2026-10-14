import Foundation
import KokoroSpike
import MisakiSwift
import MLX
import XCTest
@testable import KokoroSpikeEngine

/// Runs the real model. Opt-in, needs `setup.sh` and an Xcode build (MLX's Metal library isn't
/// built by `swift test`). The bundle path lets SwiftPM's resource accessors find the bundles
/// next to the test runner:
///
///     TEST_RUNNER_KOKORO_SPIKE_SMOKE=1 \
///     TEST_RUNNER_PACKAGE_RESOURCE_BUNDLE_PATH=<derived data>/Build/Products/Debug \
///     xcodebuild test -scheme KokoroSpike -destination 'platform=macOS' \
///       -derivedDataPath <derived data> -only-testing:KokoroSpikeEngineTests
final class KokoroSpikeModelSmokeTests: XCTestCase {
    func test_generate_everyLineWithAPlainAndABlendedVoice_producesSpeechLevelAudio() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["KOKORO_SPIKE_SMOKE"] == "1", "Set KOKORO_SPIKE_SMOKE=1 to run")
        let models = try XCTUnwrap(Bundle.module.url(forResource: "Models", withExtension: nil))
        let modelURL = models.appendingPathComponent("kokoro-v1_0.safetensors")
        let voicesURL = models.appendingPathComponent("voices.npz")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: modelURL.path), "Run setup.sh first")

        let loadStart = Date()
        let model = try KokoroSpikeModel(modelURL: modelURL, voicesURL: voicesURL)
        print("[KokoroSpikeSmoke] load \(Self.seconds(since: loadStart)), \(Self.memory())")

        let heart = KokoroSpikeVoice.catalog[0]
        let puck = KokoroSpikeVoice.catalog.first { $0.id == "am_puck" }!
        let emma = KokoroSpikeVoice.catalog.first { $0.id == "bf_emma" }!
        let voices: [(KokoroSpikeVoice, KokoroSpikeVoice, Float)] = [(heart, heart, 0), (heart, puck, 0.5), (emma, emma, 0)]

        for (voice, blendVoice, blend) in voices {
            for line in KokoroSpikeLine.allCases {
                let request = KokoroSpikeRequest(
                    chunks: KokoroSpikeSentences.chunks(line.text),
                    voice: voice,
                    blendVoice: blendVoice,
                    blend: blend,
                    pitchCents: 0,
                    speed: 1
                )
                var samples: [Float] = []
                var firstChunk: TimeInterval?
                let start = Date()
                for chunk in request.chunks {
                    samples += try model.generate(chunk, request: request)
                    if firstChunk == nil { firstChunk = Date().timeIntervalSince(start) }
                }
                let total = Date().timeIntervalSince(start)
                let audio = Double(samples.count) / 24_000
                let peak = samples.map(abs).max() ?? 0
                print(String(
                    format: "[KokoroSpikeSmoke] %@ %@+%.0f%%: first chunk %.3f s, total %.3f s, audio %.2f s, %.1fx real time, peak %.2f",
                    line.rawValue, voice.id, blend * 100, firstChunk ?? 0, total, audio, audio / total, peak
                ))

                print("[KokoroSpikeSmoke] \(Self.memory())")

                XCTAssertGreaterThan(audio, 2, "\(line) \(voice.id)")
                // Speech peaks well under 1; the mlx-swift 0.30.2 bug gave values around ±11 (static).
                XCTAssertLessThan(peak, 1.5, "\(line) \(voice.id)")
                XCTAssertGreaterThan(peak, 0.05, "\(line) \(voice.id)")
            }
        }
    }

    /// The patched MisakiSwift finds its dictionaries: a dictionary word gets the dictionary
    /// pronunciation, not the BART guess ("kˈɑlənᵊl"), and missing dictionaries fail silently upstream.
    func test_phonemize_usesTheBundledDictionaries() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["KOKORO_SPIKE_SMOKE"] == "1", "Set KOKORO_SPIKE_SMOKE=1 to run")

        let us = EnglishG2P(british: false).phonemize(text: "The colonel waters Sprout on Wednesday.").0
        let gb = EnglishG2P(british: true).phonemize(text: "The colonel waters Sprout on Wednesday.").0
        print("[KokoroSpikeSmoke] US: \(us) | GB: \(gb)")

        XCTAssertTrue(us.contains("kˈɜɹnᵊl"), us)
        XCTAssertTrue(us.contains("wˈɛnzdˌA"), us)
        XCTAssertFalse(gb.isEmpty)
    }

    private static func memory() -> String {
        guard let memory = KokoroSpikeMemory.current() else { return "memory unknown" }
        let mlx = Memory.snapshot()
        return String(
            format: "memory %.0f MB now, %.0f MB peak (MLX active %.0f MB, cache %.0f MB, peak %.0f MB)",
            Double(memory.currentBytes) / 1_048_576, Double(memory.peakBytes) / 1_048_576,
            Double(mlx.activeMemory) / 1_048_576, Double(mlx.cacheMemory) / 1_048_576, Double(mlx.peakMemory) / 1_048_576
        )
    }

    private static func seconds(since date: Date) -> String {
        String(format: "%.3f s", Date().timeIntervalSince(date))
    }
}
