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
        .library(name: "PlantDevice", targets: ["PlantDevice"]),
        .library(name: "PlantHistory", targets: ["PlantHistory"]),
        .library(name: "PlantHistoryiOS", targets: ["PlantHistoryiOS"]),
        .library(name: "PlantChat", targets: ["PlantChat"]),
        .library(name: "PlantChatiOS", targets: ["PlantChatiOS"]),
        .library(name: "PlantFace", targets: ["PlantFace"]),
        .library(name: "PlantFaceiOS", targets: ["PlantFaceiOS"])
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0")
    ],
    targets: [
        .target(name: "PlantShared"),
        .target(name: "PlantMonitor", dependencies: ["PlantShared"], resources: [.process("Resources")]),
        .target(name: "PlantMonitoriOS", dependencies: ["PlantMonitor", "PlantShared"]),
        .target(name: "PlantDevice", dependencies: ["PlantShared"]),
        .target(name: "PlantHistory", dependencies: ["PlantShared"], resources: [.process("Resources")]),
        .target(name: "PlantHistoryiOS", dependencies: ["PlantHistory", "PlantShared"]),
        .target(name: "PlantChat", dependencies: ["PlantShared"], resources: [.process("Resources")]),
        .target(name: "PlantChatiOS", dependencies: ["PlantChat", "PlantShared"]),
        .target(name: "PlantFace", dependencies: ["PlantShared"]),
        .target(name: "PlantFaceiOS", dependencies: ["PlantFace", "PlantShared"]),
        .testTarget(name: "PlantSharedTests", dependencies: ["PlantShared"]),
        .testTarget(name: "PlantMonitorTests", dependencies: ["PlantMonitor", "PlantShared"]),
        .testTarget(
            name: "PlantMonitoriOSTests",
            dependencies: ["PlantMonitoriOS", "PlantMonitor", "PlantShared", "ViewInspector"]
        ),
        .testTarget(name: "PlantDeviceTests", dependencies: ["PlantDevice", "PlantShared"]),
        .testTarget(name: "PlantHistoryTests", dependencies: ["PlantHistory", "PlantShared"]),
        .testTarget(
            name: "PlantHistoryiOSTests",
            dependencies: ["PlantHistoryiOS", "PlantHistory", "PlantShared", "ViewInspector"]
        ),
        .testTarget(name: "PlantChatTests", dependencies: ["PlantChat", "PlantShared"]),
        .testTarget(
            name: "PlantChatiOSTests",
            dependencies: ["PlantChatiOS", "PlantChat", "PlantShared", "ViewInspector"]
        ),
        .testTarget(name: "PlantFaceTests", dependencies: ["PlantFace", "PlantShared"]),
        .testTarget(
            name: "PlantFaceiOSTests",
            dependencies: ["PlantFaceiOS", "PlantFace", "PlantShared", "ViewInspector"]
        )
    ]
)
