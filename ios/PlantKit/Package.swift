// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PlantKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(name: "PlantKit", targets: ["PlantKit"]),
    ],
    targets: [
        .target(name: "PlantKit"),
        .testTarget(name: "PlantKitTests", dependencies: ["PlantKit"]),
    ]
)
