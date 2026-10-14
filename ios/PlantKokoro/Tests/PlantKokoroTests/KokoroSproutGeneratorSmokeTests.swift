import KokoroSwift
import MLX
import MLXRandom
import MisakiSwift
import XCTest
@testable import PlantKokoro

/// Runs the real model. Opt-in, needs `make -C tools/kokoro assets` and an Xcode build (MLX's Metal
/// library isn't built by `swift test`). The bundle path lets SwiftPM's resource accessors find the
/// bundles next to the test runner:
///
///     TEST_RUNNER_PLANT_KOKORO_SMOKE=1 \
///     TEST_RUNNER_PACKAGE_RESOURCE_BUNDLE_PATH=<derived data>/Build/Products/Debug \
///     xcodebuild test -scheme PlantKokoro -destination 'platform=macOS' \
///       -derivedDataPath <derived data> -only-testing:PlantKokoroTests
@MainActor
final class KokoroSproutGeneratorSmokeTests: XCTestCase {
    private static let twoSentences = "Your soil is a little dry today. Could I have some water, please?"

    func test_generate_afterPrewarm_producesSpeechLevelAudio() async throws {
        let sut = try makeSUT()
        try await sut.prewarm()

        for (text, minimumSeconds) in [("Hi.", 0.2), (Self.twoSentences, 2.0)] {
            let samples = try await sut.generate(text, speed: 1)
            let peak = samples.map(abs).max() ?? 0

            XCTAssertGreaterThan(Double(samples.count) / 24_000, minimumSeconds, text)
            // Speech peaks well under 1; the mlx-swift 0.30.2 bug gave values around ±11 (static).
            XCTAssertLessThan(peak, 1.5, text)
            XCTAssertGreaterThan(peak, 0.05, text)
        }
    }

    /// The shipped weights have weight norm folded in at build time. This folds the unfolded fp16 weights
    /// the way kokoro-ios did on every call (fp16 math), and checks that both models say the same thing.
    /// Needs the unfolded copy that `make -C tools/kokoro assets` leaves in tools/kokoro/.cache.
    func test_foldedWeights_sayTheSameSentenceAsUnfoldedWeights() throws {
        try skipUnlessOptedIn()
        let folded = try resourceURL("kokoro-f16.safetensors")
        let unfolded = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("tools/kokoro/.cache/kokoro-f16-unfolded.safetensors")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: unfolded.path), "Run make -C tools/kokoro assets first")
        let voice = try XCTUnwrap(MLX.loadArrays(url: resourceURL("sprout.safetensors"))["sprout"])
        let text = "Your soil is a little dry today."

        let reference = try Self.foldAtRuntime(unfolded)
        defer { try? FileManager.default.removeItem(at: reference) }
        let expected = try Self.speak(text, voice: voice, weights: reference)
        let actual = try Self.speak(text, voice: voice, weights: folded)

        XCTAssertEqual(actual.count, expected.count)
        let count = min(actual.count, expected.count)
        var squaredError: Double = 0
        var squaredSignal: Double = 0
        for index in 0..<count {
            squaredError += Double(actual[index] - expected[index]) * Double(actual[index] - expected[index])
            squaredSignal += Double(expected[index]) * Double(expected[index])
        }
        let waveform = (squaredError / max(squaredSignal, 1e-12)).squareRoot()
        let envelope = Self.relativeDifference(Self.loudness(actual), Self.loudness(expected))
        print("folded vs unfolded: \(count) samples, waveform RMS difference \(waveform), loudness envelope difference \(envelope)")
        // Rounding the weights to fp16 differently already moves the waveform by a few percent (the
        // vocoder's phases are sensitive), so the waveform bound is loose. The envelope is what you hear.
        XCTAssertLessThan(waveform, 0.12)
        XCTAssertLessThan(envelope, 0.02)
    }

    /// RMS of every 20 ms.
    private static func loudness(_ samples: [Float]) -> [Double] {
        stride(from: 0, to: samples.count - 479, by: 480).map { start in
            let sum = samples[start..<start + 480].reduce(0.0) { $0 + Double($1) * Double($1) }
            return (sum / 480).squareRoot()
        }
    }

    private static func relativeDifference(_ a: [Double], _ b: [Double]) -> Double {
        let error = zip(a, b).reduce(0.0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
        let signal = b.reduce(0.0) { $0 + $1 * $1 }
        return (error / max(signal, 1e-12)).squareRoot()
    }

    /// A dictionary word gets the dictionary pronunciation, not the BART guess ("kˈɑlənᵊl").
    /// Missing dictionaries fail silently, so this catches a broken resource load.
    func test_phonemize_usesTheBundledDictionaries() throws {
        try skipUnlessOptedIn()

        let phonemes = EnglishG2P(british: false).phonemize(text: "The colonel waters Sprout on Wednesday.").0

        XCTAssertTrue(phonemes.contains("kˈɜɹnᵊl"), phonemes)
        XCTAssertTrue(phonemes.contains("wˈɛnzdˌA"), phonemes)
    }

    func test_generate_beforePrewarm_throwsNotLoaded() async throws {
        let sut = try makeSUT()

        await assertThrows(.notLoaded) { _ = try await sut.generate("Hi.", speed: 1) }
    }

    func test_generate_duringPrewarm_waitsAndSucceeds() async throws {
        let sut = try makeSUT()

        async let prewarm: Void = sut.prewarm()
        await Task.yield()
        let samples = try await sut.generate("Hi.", speed: 1)
        try await prewarm

        XCTAssertFalse(samples.isEmpty)
    }

    func test_generate_afterUnload_throwsNotLoaded() async throws {
        let sut = try makeSUT()
        try await sut.prewarm()

        sut.unload()

        await assertThrows(.notLoaded) { _ = try await sut.generate("Hi.", speed: 1) }
    }

    func test_prewarm_afterUnload_loadsAgain() async throws {
        let sut = try makeSUT()
        try await sut.prewarm()
        sut.unload()

        try await sut.prewarm()
        let samples = try await sut.generate("Hi.", speed: 1)

        XCTAssertFalse(samples.isEmpty)
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) throws -> KokoroSproutGenerator {
        try skipUnlessOptedIn()
        let resources = try XCTUnwrap(Bundle.module.resourceURL, file: file, line: line)
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: resources.appendingPathComponent("kokoro-f16.safetensors").path),
            "Run make -C tools/kokoro assets first"
        )
        let sut = KokoroSproutGenerator(resources: resources)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private func resourceURL(_ name: String) throws -> URL {
        let url = try XCTUnwrap(Bundle.module.resourceURL).appendingPathComponent(name)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Run make -C tools/kokoro assets first")
        return url
    }

    /// Same seed, so the noise sources match and only the weights differ.
    private static func speak(_ text: String, voice: MLXArray, weights: URL) throws -> [Float] {
        MLXRandom.seed(42)
        let tts = KokoroTTS(modelPath: weights, g2p: .misaki)
        return try tts.generateAudio(voice: voice, language: .enUS, text: text, speed: 1).0
    }

    /// Writes a copy of the unfolded weights with `weight_g` / `weight_v` replaced by
    /// `g * v / (||v|| + 1e-7)`, computed in fp16 with the norm over all axes but 0.
    private static func foldAtRuntime(_ unfolded: URL) throws -> URL {
        var weights = try MLX.loadArrays(url: unfolded)
        for key in Array(weights.keys) where key.hasSuffix(".weight_v") {
            let prefix = String(key.dropLast("weight_v".count))
            let v = weights[key]!
            let g = weights[prefix + "weight_g"]!
            let axes = Array(1..<v.ndim)
            let norm = MLX.sqrt(MLX.sum(v * v, axes: axes, keepDims: true))
            weights[prefix + "weight"] = v / (norm + 1e-7) * g
            weights[key] = nil
            weights[prefix + "weight_g"] = nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kokoro-runtime-folded-\(UUID().uuidString).safetensors")
        try MLX.save(arrays: weights, url: url)
        return url
    }

    private func skipUnlessOptedIn() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PLANT_KOKORO_SMOKE"] == "1", "Set PLANT_KOKORO_SMOKE=1 to run")
    }

    private func assertThrows(
        _ expected: KokoroSproutGenerator.GeneratorError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? KokoroSproutGenerator.GeneratorError, expected, file: file, line: line)
        }
    }

    private func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
}
