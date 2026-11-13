// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrackpadHaptics",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "haptyk", targets: ["haptyk"]),
        .library(name: "HapticCore", targets: ["HapticCore"]),
        .executable(name: "haptic-lab", targets: ["haptic-lab"]),
        .executable(name: "haptic-web", targets: ["haptic-web"]),
    ],
    targets: [
        .target(name: "HapticCore"),
        .target(name: "HaptykKit", dependencies: ["HapticCore"]),
        .executableTarget(name: "haptyk", dependencies: ["HaptykKit"]),
        .executableTarget(name: "haptic-lab", dependencies: ["HapticCore"]),
        .executableTarget(name: "haptic-web", dependencies: ["HapticCore"]),
        .testTarget(name: "HaptykKitTests", dependencies: ["HaptykKit"]),
    ]
)
