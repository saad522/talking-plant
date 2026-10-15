// swift-tools-version: 6.2
import PackageDescription

// Sprout's voice (docs/plans/M5c-kokoro.md). Linked only by the app. PlantKit never imports it.
// KokoroSwift and MisakiSwift are vendored (see Vendor/README.md), so the only fetched dependency is mlx-swift.
// The model files in Sources/PlantKokoro/Resources come from `make -C tools/kokoro assets`.
let package = Package(
    name: "PlantKokoro",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "PlantKokoro", targets: ["PlantKokoro"])
    ],
    dependencies: [
        // 0.30.6 has the A18/A19 fixes.
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.30.6")
    ],
    targets: [
        .target(
            name: "PlantKokoro",
            dependencies: [
                "KokoroSwift",
                .product(name: "MLX", package: "mlx-swift")
            ],
            // Listed file by file: a resource directory makes the bundle fail codesign.
            resources: [
                .process("Resources/kokoro-f16.safetensors"),
                .process("Resources/sprout.safetensors")
            ]
        ),
        .target(
            name: "KokoroSwift",
            dependencies: [
                "MisakiSwift",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXFFT", package: "mlx-swift")
            ],
            path: "Vendor/KokoroSwift/Sources/KokoroSwift",
            resources: [
                .copy("../../Resources/config.json")
            ]
        ),
        .target(
            name: "MisakiSwift",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift")
            ],
            path: "Vendor/MisakiSwift/Sources/MisakiSwift",
            resources: [
                .copy("../../Resources/us_bart.safetensors"),
                .copy("../../Resources/us_bart_config.json"),
                .copy("../../Resources/us_gold.json"),
                .copy("../../Resources/us_silver.json")
            ]
        ),
        // Opt-in smoke test of the real model (see the test's comment).
        .testTarget(
            name: "PlantKokoroTests",
            dependencies: [
                "PlantKokoro", "KokoroSwift", "MisakiSwift",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift")
            ]
        )
    ]
)
