// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "haptyq",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "haptyq", targets: ["haptyq"]),
        .library(name: "HapticCore", targets: ["HapticCore"]),
        .executable(name: "haptic-lab", targets: ["haptic-lab"]),
        .executable(name: "haptic-web", targets: ["haptic-web"]),
    ],
    targets: [
        .target(name: "HapticCore"),
        .target(name: "HaptyqKit", dependencies: ["HapticCore"]),
        .executableTarget(name: "haptyq", dependencies: ["HaptyqKit"]),
        .executableTarget(name: "haptic-lab", dependencies: ["HapticCore"]),
        .executableTarget(name: "haptic-web", dependencies: ["HapticCore"]),
        .testTarget(name: "HaptyqKitTests", dependencies: ["HaptyqKit"]),
    ]
)
