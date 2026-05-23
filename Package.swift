// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Loki",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // Engine, safety layer and prank catalog. No @main / SwiftUI app entry,
        // so it stays unit-testable.
        .target(
            name: "LokiCore"
        ),
        // The actual menu-bar app. Thin SwiftUI shell on top of LokiCore.
        .executableTarget(
            name: "Loki",
            dependencies: ["LokiCore"]
        ),
        .testTarget(
            name: "LokiCoreTests",
            dependencies: ["LokiCore"]
        ),
    ]
)
