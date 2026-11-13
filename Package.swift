// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrackpadHaptics",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "tremor", targets: ["tremor"]),
        .library(name: "HapticCore", targets: ["HapticCore"]),
        .executable(name: "haptic-lab", targets: ["haptic-lab"]),
        .executable(name: "haptic-web", targets: ["haptic-web"]),
    ],
    targets: [
        .target(name: "HapticCore"),
        .target(name: "TremorKit", dependencies: ["HapticCore"]),
        .executableTarget(name: "tremor", dependencies: ["TremorKit"]),
        .executableTarget(name: "haptic-lab", dependencies: ["HapticCore"]),
        .executableTarget(name: "haptic-web", dependencies: ["HapticCore"]),
        .testTarget(name: "TremorKitTests", dependencies: ["TremorKit"]),
    ]
)
