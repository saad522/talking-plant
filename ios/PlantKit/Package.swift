// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PlantKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "PlantShared", targets: ["PlantShared"]),
        .library(name: "PlantMonitor", targets: ["PlantMonitor"]),
        .library(name: "PlantMonitoriOS", targets: ["PlantMonitoriOS"]),
        .library(name: "PlantDevice", targets: ["PlantDevice"])
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0")
    ],
    targets: [
        .target(name: "PlantShared"),
        .target(name: "PlantMonitor", dependencies: ["PlantShared"], resources: [.process("Resources")]),
        .target(name: "PlantMonitoriOS", dependencies: ["PlantMonitor", "PlantShared"]),
        .target(name: "PlantDevice", dependencies: ["PlantShared"]),
        .testTarget(name: "PlantSharedTests", dependencies: ["PlantShared"]),
        .testTarget(name: "PlantMonitorTests", dependencies: ["PlantMonitor", "PlantShared"]),
        .testTarget(
            name: "PlantMonitoriOSTests",
            dependencies: ["PlantMonitoriOS", "PlantMonitor", "PlantShared", "ViewInspector"]
        ),
        .testTarget(name: "PlantDeviceTests", dependencies: ["PlantDevice", "PlantShared"])
    ]
)
