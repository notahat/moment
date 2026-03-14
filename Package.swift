// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "moment",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "moment",
            dependencies: ["MomentCore"],
        ),
        .target(
            name: "MomentCore",
        ),
        .testTarget(
            name: "MomentCoreTests",
            dependencies: ["MomentCore"],
        ),
    ],
)
