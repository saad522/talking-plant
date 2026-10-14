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
