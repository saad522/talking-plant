// swift-tools-version: 6.2
import PackageDescription

// Kokoro spike (docs/spikes/kokoro.md). DEBUG-only listening test, not production code.
// Run setup.sh first: it vendors patched kokoro-ios / MisakiSwift into Vendor/ and fetches the model.
// Delete this folder, the package reference in Xcode and the `#if DEBUG` voice spike bits to remove it.
let package = Package(
    name: "KokoroSpike",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "KokoroSpikeiOS", targets: ["KokoroSpikeiOS", "KokoroSpikeEngine", "KokoroSpike"])
    ],
    dependencies: [
        // kokoro-ios 1.0.11 and MisakiSwift 1.0.6 with patches/*.patch (see setup.sh).
        .package(path: "Vendor/kokoro-ios"),
        .package(path: "Vendor/MisakiSwift"),
        // The same exact versions the patched packages pin.
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.30.6"),
        .package(url: "https://github.com/mlalma/MLXUtilsLibrary.git", exact: "0.0.6")
    ],
    targets: [
        // Pure logic: lines, voices, sentence chunks, the view model. Foundation only, fast to test.
        .target(name: "KokoroSpike"),
        // Kokoro (MLX) + AVAudioEngine. Only this target knows about MLX.
        .target(
            name: "KokoroSpikeEngine",
            dependencies: [
                "KokoroSpike",
                .product(name: "KokoroSwift", package: "kokoro-ios"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXUtilsLibrary", package: "MLXUtilsLibrary")
            ],
            resources: [.copy("Resources/Models")]
        ),
        // SwiftUI screen and composer.
        .target(name: "KokoroSpikeiOS", dependencies: ["KokoroSpike", "KokoroSpikeEngine"]),
        .testTarget(name: "KokoroSpikeTests", dependencies: ["KokoroSpike"]),
        // Opt-in smoke test of the real model (see the test's comment).
        .testTarget(
            name: "KokoroSpikeEngineTests",
            dependencies: ["KokoroSpike", "KokoroSpikeEngine", .product(name: "MisakiSwift", package: "MisakiSwift")]
        )
    ]
)
