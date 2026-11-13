// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrackpadHaptics",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HapticCore", targets: ["HapticCore"]),
        .executable(name: "haptic-lab", targets: ["haptic-lab"]),
        .executable(name: "haptic-daemon", targets: ["haptic-daemon"]),
        .executable(name: "haptic-web", targets: ["haptic-web"]),
    ],
    targets: [
        .target(name: "HapticCore"),
        .executableTarget(name: "haptic-lab", dependencies: ["HapticCore"]),
        .executableTarget(name: "haptic-daemon", dependencies: ["HapticCore"]),
        .executableTarget(name: "haptic-web", dependencies: ["HapticCore"]),
    ]
)
